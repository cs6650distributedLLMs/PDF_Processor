import flow from 'lodash/flow.js';

export const withErrorLogging =
  (handler) =>
  async (...args) => {
    try {
      return await handler(...args);
    } catch (err) {
      console.error(err);
      throw err;
    }
  };

export const withEventLogging =
  (handler) =>
  async (...args) => {
    console.log('INPUT: ', JSON.stringify(args));
    const result = await handler(...args);
    console.log('OUTPUT: ', JSON.stringify(result));
    return result;
  };

export const withLogging = flow(withEventLogging, withErrorLogging);
