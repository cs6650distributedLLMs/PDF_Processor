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
  async (...args) =>
    await handler(...args);

export const withLogging = flow(withEventLogging, withErrorLogging);

/**
 * Extracts the media ID from an S3 key.
 * An S3 key is in the format `{prefix}/{mediaId}/{mediaName}`
 * @param {string} s3Key The media S3 key
 * @return {string} The media ID
 */
export const getMediaId = (s3Key) => {
  const keyArray = s3Key.split('/');

  if (keyArray.length === 1) {
    return keyArray[0];
  }

  return keyArray[1];
};
