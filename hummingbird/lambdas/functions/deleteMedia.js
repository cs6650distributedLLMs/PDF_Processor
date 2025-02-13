import { withLogging } from '../common.js';

const getHandler = () => {
  return async (event, context) => {
    console.log('deleteMedia');
    console.log({ event, context });
    // for (const record of event.Records) {
    //   console.log('record: ', record);
    // }
  };
};

export const handler = withLogging(getHandler());
