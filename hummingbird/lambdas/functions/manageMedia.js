const opentelemetry = require('@opentelemetry/api');
const { withLogging } = require('../common.js');
const { init: initializeLogger, getLogger } = require('../logger.js');
const deleteMediaHandler = require('../eventHandlers/deleteMediaHandler.js');
const resizeMediaHandler = require('../eventHandlers/resizeMediaHandler.js');

const tracer = opentelemetry.trace.getTracer('manage-media-lambda');

initializeLogger({ service: 'manageMediaLambda' });
const logger = getLogger();

const DELETE_EVENT_TYPE = 'media.v1.delete';
const RESIZE_EVENT_TYPE = 'media.v1.resize';

const getHandler = () => {
  return async (event, context) => {
    tracer.startActiveSpan('manage-media', async (span) => {
      logger.info('Media management lambda triggered', { event });

      for (const record of event.Records) {
        const body = JSON.parse(record.body);
        const message = JSON.parse(body.Message);
        const { mediaId, width } = message?.payload || {};
        const type = message.type;

        span.setAttributes({
          'media.id': mediaId,
          width: width,
        });

        switch (type) {
          case DELETE_EVENT_TYPE:
            await deleteMediaHandler({ mediaId, span });
            break;
          case RESIZE_EVENT_TYPE:
            await resizeMediaHandler({ mediaId, width, span });
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
