const { ConditionalCheckFailedException } = require('@aws-sdk/client-dynamodb');
const opentelemetry = require('@opentelemetry/api');
const { getMediaId, withLogging } = require('../common.js');
const { setMediaStatus } = require('../clients/dynamodb.js');
const { MEDIA_STATUS } = require('../core/constants.js');
const { init: initializeLogger, getLogger } = require('../logger.js');
const { successesCounter, failuresCounter } = require('../observability.js');
const extractPdfHandler = require('../eventHandlers/extractPdfHandler.js');

initializeLogger({ service: process.env.AWS_LAMBDA_FUNCTION_NAME });
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
        logger.info(`Extracting text from PDF with id ${mediaId}.`);
        span.setAttribute('media.id', mediaId);
        await extractPdfHandler({ mediaId, span });
        successesCounter.add(1, { scope: metricScope });
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

        await setMediaStatus({ mediaId, newStatus: MEDIA_STATUS.ERROR });
        logger.error(`Failed to process media ${mediaId}`, error);
        span.end();
        failuresCounter.add(1, { scope: metricScope });
        throw error;
      } finally {
        logger.info('Flushing OpenTelemetry signals');
        await global.customInstrumentation.metricReader.forceFlush();
        await global.customInstrumentation.traceExporter.forceFlush();
      }
    });
  };
};

const handler = withLogging(getHandler());

module.exports = { handler };
