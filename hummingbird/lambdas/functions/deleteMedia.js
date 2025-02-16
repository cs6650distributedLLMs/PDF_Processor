import { withLogging } from '../common.js';

const DELETE_EVENT_TYPE = 'media.v1.delete';

const getHandler = () => {
  return async (event, context) => {
    console.log('deleteMedia');
    for (const record of event.Records) {
      const message = JSON.parse(record.body).Message;
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
      // Delete media from storage
      // Delete media from database
    }
  };
};

export const handler = withLogging(getHandler());
