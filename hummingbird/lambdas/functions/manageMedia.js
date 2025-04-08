const opentelemetry = require('@opentelemetry/api');
const { withLogging } = require('../common.js');
const { init: initializeLogger, getLogger } = require('../logger.js');
const deleteMediaHandler = require('../eventHandlers/deleteMediaHandler.js');
const extractPdfHandler = require('../eventHandlers/extractPdfHandler.js');
const summarizeTextHandler = require('../eventHandlers/summarizeTextHandler.js');

const tracer = opentelemetry.trace.getTracer('manage-media-lambda');

initializeLogger({ service: process.env.AWS_LAMBDA_FUNCTION_NAME });
const logger = getLogger();

const DELETE_EVENT_TYPE = 'media.v1.delete';
const SUMMARIZE_EVENT_TYPE = 'media.v1.summarize';
const SUMMARIZE_TEXT_EVENT_TYPE = 'media.v1.summarize.text';

const getHandler = () => {
  return async (event, context) => {
    await tracer.startActiveSpan('manage-media', async (span) => {
      logger.info('Media management lambda triggered', { event });

      for (const record of event.Records) {
        const body = JSON.parse(record.body);
        const message = JSON.parse(body.Message);
        const { mediaId, style, mediaName } = message?.payload || {};
        const type = message.type;

        span.setAttributes({
          'media.id': mediaId,
          'media.style': style,
        });

        switch (type) {
          case DELETE_EVENT_TYPE:
            await deleteMediaHandler({ mediaId, span });
            break;
          case SUMMARIZE_EVENT_TYPE:
            await extractPdfHandler({ mediaId, style, span });
            break;
          case SUMMARIZE_TEXT_EVENT_TYPE:
            await summarizeTextHandler({ mediaId, mediaName, style, span });
            break;
          default:
            logger.info(`Skipping message with type ${type}. Not supported.`);
            break;
        }

        span.end();
      }
    });
  };
};

const handler = withLogging(getHandler());

module.exports = { handler };
