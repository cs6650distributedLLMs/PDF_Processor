const opentelemetry = require('@opentelemetry/api');
const { withLogging } = require('../common.js');
const { init: initializeLogger, getLogger } = require('../logger.js');
const deleteMediaHandler = require('../eventHandlers/deleteMediaHandler.js');
const summarizeTextHandler = require('../eventHandlers/summarizeTextHandler.js');
const { EVENTS } = require('../core/constants.js');

const tracer = opentelemetry.trace.getTracer('manage-media-lambda');

initializeLogger({ service: process.env.AWS_LAMBDA_FUNCTION_NAME });
const logger = getLogger();

const getHandler = () => {
  return async (event, context) => {
    await tracer.startActiveSpan('manage-media', async (span) => {
      logger.info('Media management lambda triggered', { event });

      for (const record of event.Records) {
        const body = JSON.parse(record.body);
        const message = JSON.parse(body.Message);
        const { mediaId, style } = message?.payload || {};
        const type = message.type;

        span.setAttributes({ 'media.id': mediaId, 'media.style': style });

        switch (type) {
          case EVENTS.DELETE_MEDIA.type:
            await deleteMediaHandler({ mediaId, span });
            break;
          case EVENTS.SUMMARIZE_TEXT.type:
            await summarizeTextHandler({ mediaId, style, span });
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
