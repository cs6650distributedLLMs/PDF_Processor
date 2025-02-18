import { deleteMedia } from '../../src/clients/dynamodb.js';
import { deleteMediaFile } from '../../src/clients/s3.js';
import { withLogging } from '../common.js';
import { MEDIA_STATUS } from '../../src/core/constants.js';

const DELETE_EVENT_TYPE = 'media.v1.delete';

const getHandler = () => {
  return async (event, context) => {
    console.log('deleteMedia');
    for (const record of event.Records) {
      const body = JSON.parse(record.body);
      const message = JSON.parse(body.Message);
      const type = message.type;

      if (type !== DELETE_EVENT_TYPE) {
        console.log(`Skipping message with type ${type}. Not supported.`);
        continue;
      }

      const mediaId = message.payload?.mediaId;

      if (!mediaId) {
        console.log('Skipping message with no mediaId.');
        continue;
      }

      console.log(`Deleting media with id ${mediaId}.`);

      const deletedMedia = await deleteMedia(mediaId);

      if (!deletedMedia) {
        console.log(`Media with id ${mediaId} not found.`);
        continue;
      }

      await deleteMediaFile({ mediaId });

      if (deletedMedia.status === MEDIA_STATUS.COMPLETE) {
        await deleteMediaFile({ mediaId, keyPrefix: 'resized' });
      }

      console.log(`Deleted media with id ${mediaId}.`);
    }
  };
};

export const handler = withLogging(getHandler());
