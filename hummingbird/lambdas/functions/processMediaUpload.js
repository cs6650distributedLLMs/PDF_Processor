const sharp = require('sharp');
const { ConditionalCheckFailedException } = require('@aws-sdk/client-dynamodb');
const opentelemetry = require('@opentelemetry/api');
const { getMediaId, withLogging } = require('../common.js');
const {
  setMediaStatus,
  setMediaStatusConditionally,
} = require('../clients/dynamodb.js');
const { getMediaFile, uploadMediaToStorage } = require('../clients/s3.js');
const { MEDIA_STATUS } = require('../constants.js');
const { init: initializeLogger, getLogger } = require('../logger.js');

initializeLogger({ service: 'processMediaUploadLambda' });
const logger = getLogger();

const tracer = opentelemetry.trace.getTracer('process-media-upload-lambda');

/**
 * Gets the handler for the processMediaUpload Lambda function.
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

    tracer.startActiveSpan('process-media-upload', async (span) => {
      try {
        logger.info(`Processing media ${mediaId}.`);

        span.setAttribute('media.id', mediaId);

        const { name: mediaName, width } = await setMediaStatusConditionally({
          mediaId,
          newStatus: MEDIA_STATUS.PROCESSING,
          expectedCurrentStatus: MEDIA_STATUS.PENDING,
        });

        logger.info('Media status set to PROCESSING');

        const image = await getMediaFile({ mediaId, mediaName });

        logger.info('Got media file');

        const resizeMedia = await processMediaWithSharp({
          imageBuffer: image,
          width,
        });

        logger.info('Processed media');

        await uploadMediaToStorage({
          mediaId,
          mediaName,
          body: resizeMedia,
          keyPrefix: 'resized',
        });

        logger.info('Uploaded processed media');

        await setMediaStatusConditionally({
          mediaId,
          newStatus: MEDIA_STATUS.COMPLETE,
          expectedCurrentStatus: MEDIA_STATUS.PROCESSING,
        });

        logger.info(`Done processing media ${mediaId}.`);

        span.setStatus({ code: opentelemetry.SpanStatusCode.OK });
        span.end();
      } catch (err) {
        span.setStatus({ code: opentelemetry.SpanStatusCode.ERROR });

        if (err instanceof ConditionalCheckFailedException) {
          span.end();
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
        span.end();
        throw err;
      }
    });
  };
};

/**
 * Resizes a media file to a specific width and converts it to JPEG format.
 * @param {object} param0 The function parameters
 * @param {Uint8Array} param0.imageBuffer The image buffer to resize
 * @param {string} width The size to resize the uploaded image to
 * @returns {Promise<Buffer>} The resized image buffer
 */
const processMediaWithSharp = async ({ imageBuffer, width }) => {
  const DEFAULT_IMAGE_WIDTH_PX = 500;
  const imageSizePx = parseInt(width) || DEFAULT_IMAGE_WIDTH_PX;
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
