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

initializeLogger({ service: 'processMediaLambda' });
const logger = getLogger();

/**
 * Gets the handler for the processMedia Lambda function.
 * @returns {Function} The Lambda function handler
 * @see https://docs.aws.amazon.com/lambda/latest/dg/nodejs-handler.html
 */
const getHandler = () => {
  /**
   * Processes a media file uploaded to S3.
   * @param {object} event The S3 event object
   * @param {object} context The Lambda execution context
   * @returns {Promise<void>}
   */
  return async (event, context) => {
    const mediaId = getMediaId(event.Records[0].s3.object.key);

    try {
      logger.info(`Processing image ${mediaId}.`);

      const { name: mediaName, targetSize } = await setMediaStatusConditionally(
        {
          mediaId,
          newStatus: MEDIA_STATUS.PROCESSING,
          expectedCurrentStatus: MEDIA_STATUS.PENDING,
        }
      );

      logger.info('Media status set to PROCESSING');

      const image = await getMediaFile({ mediaId, mediaName });

      logger.info('Got media file');

      const resizedImage = await processImageWithSharp({
        imageBuffer: image,
        targetSize,
      });

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
    } catch (err) {
      if (err instanceof ConditionalCheckFailedException) {
        logger.error(
          `Media ${mediaId} not found or status is not ${MEDIA_STATUS.PROCESSING}.`
        );
        throw err;
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
 * @param {object} param0 The function parameters
 * @param {Uint8Array} param0.imageBuffer The image buffer to resize
 * @param {string} targetSize The size to resize the uploaded image to
 * @returns {Promise<Buffer>} The resized image buffer
 */
const processImageWithSharp = async ({ imageBuffer, targetSize }) => {
  const DEFAULT_IMAGE_WIDTH_PX = 500;
  const imageSizePx = parseInt(targetSize) || DEFAULT_IMAGE_WIDTH_PX;
  return await sharp(imageBuffer)
    .resize(imageSizePx)
    .composite([
      {
        input: './hummingbird-watermark.png',
        gravity: 'southeast',
      },
    ])
    .toFormat('jpeg')
    .toBuffer();
};

const handler = withLogging(getHandler());

module.exports = { handler };
