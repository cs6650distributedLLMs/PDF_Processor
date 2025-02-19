import { deleteMedia } from '../../app/clients/dynamodb.js';
import { deleteMediaFile } from '../../app/clients/s3.js';
import { withLogging } from '../common.js';
import { MEDIA_STATUS } from '../../app/core/constants.js';
import { init as initializeLogger, getLogger } from '../logger.js';

initializeLogger({ serviceName: 'deleteMediaLambda' });
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

      const mediaId = message.payload?.mediaId;

      if (!mediaId) {
        logger.info('Skipping message with no mediaId.');
        continue;
      }

      logger.info(`Deleting media with id ${mediaId}.`);

      const deletedMedia = await deleteMedia(mediaId);

      if (!deletedMedia) {
        logger.info(`Media with id ${mediaId} not found.`);
        continue;
      }

      await deleteMediaFile({ mediaId });

      if (deletedMedia.status === MEDIA_STATUS.COMPLETE) {
        await deleteMediaFile({ mediaId, keyPrefix: 'resized' });
      }

      logger.info(`Deleted media with id ${mediaId}.`);
    }
  };
};

export const handler = withLogging(getHandler());
