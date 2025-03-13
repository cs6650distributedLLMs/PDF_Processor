const { deleteMedia } = require('../clients/dynamodb.js');
const { deleteMediaFile } = require('../clients/s3.js');
const { withLogging } = require('../common.js');
const { MEDIA_STATUS } = require('../constants.js');
const { init: initializeLogger, getLogger } = require('../logger.js');

initializeLogger({ service: 'deleteMediaLambda' });
const logger = getLogger();

const DELETE_EVENT_TYPE = 'media.v1.delete';

const getHandler = () => {
  return async (event, context) => {
    logger.info('Delete media Lambda triggered', { event });

    for (const record of event.Records) {
      const body = JSON.parse(record.body);
      const message = JSON.parse(body.Message);
      const type = message.type;

      if (type !== DELETE_EVENT_TYPE) {
        logger.info(`Skipping message with type ${type}. Not supported.`);
        continue;
      }

      /** @type {string} */
      const mediaId = message.payload?.mediaId;

      if (!mediaId) {
        logger.info('Skipping message with no mediaId.');
        continue;
      }

      logger.info(`Deleting media with id ${mediaId}.`);

      const { name: mediaName, status } = await deleteMedia(mediaId);

      if (!mediaName) {
        logger.info(`Media with id ${mediaId} not found.`);
        continue;
      }

      await deleteMediaFile({ mediaId, mediaName });

      if (status !== MEDIA_STATUS.PROCESSING) {
        const keyPrefix = status === MEDIA_STATUS.ERROR ? 'uploads' : 'resized';
        await deleteMediaFile({
          mediaId,
          mediaName,
          keyPrefix,
        });
      }

      logger.info(`Deleted media with id ${mediaId}.`);
    }
  };
};

const handler = withLogging(getHandler());

module.exports = { handler };
