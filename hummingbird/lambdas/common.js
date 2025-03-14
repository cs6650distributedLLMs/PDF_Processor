const flow = require('lodash/flow.js');
const { getLogger } = require('./logger');

const logger = getLogger();

const withErrorLogging =
  (handler) =>
  async (...args) => {
    try {
      return await handler(...args);
    } catch (error) {
      logger.error(error);
      throw error;
    }
  };

const withEventLogging =
  (handler) =>
  async (...args) =>
    await handler(...args);

const withLogging = flow(withEventLogging, withErrorLogging);

/**
 * Extracts the media ID from an S3 key.
 * An S3 key is in the format `{prefix}/{mediaId}/{mediaName}`
 * @param {string} s3Key The media S3 key
 * @returns {string} The media ID
 */
const getMediaId = (s3Key) => {
  const keyArray = s3Key.split('/');

  if (keyArray.length === 1) {
    return keyArray[0];
  }

  return keyArray[1];
};

module.exports = { withLogging, getMediaId };
