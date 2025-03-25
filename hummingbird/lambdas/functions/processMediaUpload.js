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
const { successesCounter, failuresCounter } = require('../observability.js');

initializeLogger({ service: 'processMediaUploadLambda' });
const logger = getLogger();

const tracer = opentelemetry.trace.getTracer(
  'hummingbird-process-media-upload-lambda'
);

const metricScope = 'processMediaUploadLambda';

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

    await tracer.startActiveSpan('process-media-upload', async (span) => {
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

        const mediaProcessingStart = performance.now();
        const resizeMedia = await processMediaWithSharp({
          imageBuffer: image,
          width,
        });
        const mediaProcessingEnd = performance.now();

        span.addEvent('sharp.resizing.done', {
          'media.processing.duration': Math.round(
            mediaProcessingEnd - mediaProcessingStart
          ),
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

        successesCounter.add(1, {
          scope: metricScope,
        });
        span.setStatus({ code: opentelemetry.SpanStatusCode.OK });
        span.end();
      } catch (error) {
        span.setStatus({ code: opentelemetry.SpanStatusCode.ERROR });

        if (error instanceof ConditionalCheckFailedException) {
          logger.error(
            `Media ${mediaId} not found or status is not ${MEDIA_STATUS.PROCESSING}.`
          );

          span.end();
          failuresCounter.add(1, {
            scope: metricScope,
            reason: 'CONDITIONAL_CHECK_FAILURE',
          });

          throw error;
        }

        await setMediaStatus({
          mediaId,
          newStatus: MEDIA_STATUS.ERROR,
        });

        logger.error(`Failed to process media ${mediaId}`, error);

        span.end();
        failuresCounter.add(1, {
          scope: metricScope,
        });

        throw error;
      } finally {
        logger.info('Flushing OpenTelemetry signals');
        await global.customInstrumentation.metricReader.forceFlush();
        await global.customInstrumentation.traceExporter.forceFlush();
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
