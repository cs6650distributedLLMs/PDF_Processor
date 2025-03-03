const sharp = require('sharp');
const { ConditionalCheckFailedException } = require('@aws-sdk/client-dynamodb');
const { getMediaId, withLogging } = require('../common.js');
const {
  setMediaStatus,
  setMediaStatusConditionally,
} = require('../clients/dynamodb.js');
const { getMediaFile, uploadMediaToStorage } = require('../clients/s3.js');
const { MEDIA_STATUS } = require('../constants.js');
const { init: initializeLogger, getLogger } = require('../logger.js');

initializeLogger({ serviceName: 'processMediaLambda' });
const logger = getLogger();

/**
 * Gets the handler for the processMedia Lambda function.
 * @return {Function} The Lambda function handler
 * @see https://docs.aws.amazon.com/lambda/latest/dg/nodejs-handler.html
 */
const getHandler = () => {
  /**
   * Processes a media file uploaded to S3.
   * @param {object} event The S3 event object
   * @param {object} context The Lambda execution context
   * @return {Promise<void>}
   */
  return async (event, context) => {
    const mediaId = getMediaId(event.Records[0].s3.object.key);

    try {
      logger.info(`Processing image ${mediaId}.`);

      const { name: mediaName } = await setMediaStatusConditionally({
        mediaId,
        newStatus: MEDIA_STATUS.PROCESSING,
        expectedCurrentStatus: MEDIA_STATUS.PENDING,
      });

      logger.info('Media status set to PROCESSING');

      const image = await getMediaFile({ mediaId, mediaName });

      logger.info('Got media file');

      const resizedImage = await resizeImage(image);

      logger.info('Resized image');

      await uploadMediaToStorage({
        mediaId,
        mediaName,
        body: resizedImage,
        keyPrefix: 'resized',
      });

      logger.info('Uploaded resized image');

      await setMediaStatusConditionally({
        mediaId,
        newStatus: MEDIA_STATUS.COMPLETE,
        expectedCurrentStatus: MEDIA_STATUS.PROCESSING,
      });

      logger.info(`Resized image ${mediaId}.`);

      logger.info('Flushing OpenTelemetry signals');
      await global.customInstrumentation.metricReader.forceFlush();
      await global.customInstrumentation.traceExporter.forceFlush();
    } catch (err) {
      if (err instanceof ConditionalCheckFailedException) {
        logger.error(
          `Media ${mediaId} not found or status is not ${MEDIA_STATUS.PROCESSING}.`
        );
        return;
      }

      await setMediaStatus({
        mediaId,
        newStatus: MEDIA_STATUS.ERROR,
      });

      logger.error(`Failed to process media ${mediaId}`, err);
      throw err;
    }
  };
};

/**
 * Resizes an image to a specific width and converts it to JPEG format.
 * @param {Uint8Array} imageBuffer The image buffer to resize
 * @return {Promise<Buffer>} The resized image buffer
 */
const resizeImage = async (imageBuffer) => {
  const IMAGE_WIDTH_PX = 500;
  return await sharp(imageBuffer)
    .resize(IMAGE_WIDTH_PX)
    .toFormat('jpeg')
    .toBuffer();
};

const handler = withLogging(getHandler());

module.exports = { handler };
