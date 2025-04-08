const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');
const { isLocalEnv } = require('../core/utils.js');
const { EVENTS } = require('../core/constants.js');
const { getLogger } = require('../logger.js');

const logger = getLogger();

const endpoint = isLocalEnv()
  ? 'http://sns.localhost.localstack.cloud:4566'
  : undefined;

/**
 * Publishes an event to an SNS topic.
 * @param {object} param0 Function parameters
 * @param {string} param0.topicArn The ARN of the SNS topic to publish to
 * @param {object} param0.message The message to publish
 * @returns {Promise<void>}
 */
const publishEvent = async ({ topicArn, message }) => {
  try {
    const client = new SNSClient({
      endpoint,
      region: process.env.AWS_REGION,
    });

    const command = new PublishCommand({
      TopicArn: topicArn,
      Message: JSON.stringify(message),
    });

    await client.send(command);
  } catch (error) {
    logger.error(error);
    throw error;
  }
};

/**
 * Publishes a delete media event to the media management topic
 * @param {string} mediaId The ID of the media to delete
 * @returns {Promise<void>}
 */
const publishDeleteMediaEvent = async (mediaId) => {
  const message = {
    type: EVENTS.DELETE_MEDIA.type,
    payload: { mediaId },
  };

  await publishEvent({
    topicArn: EVENTS.DELETE_MEDIA.topicArn,
    message,
  });
};

/**
 * Publishes an extract PDF event to the media management topic
 * @param {object} param0 Function parameters
 * @param {string} param0.mediaId The ID of the media to summarize
 * @param {string} param0.style The style to use for the PDF summary
 * @returns {Promise<void>}
 */
const publishSummarizeMediaEvent = async ({ mediaId, style }) => {
  const message = {
    type: EVENTS.SUMMARIZE_MEDIA.type,
    payload: { mediaId, style },
  };

  await publishEvent({
    topicArn: EVENTS.SUMMARIZE_MEDIA.topicArn,
    message,
  });
};

/**
 * Publishes a summarize text event to the media management topic
 * @param {object} param0 Function parameters
 * @param {string} param0.mediaId The ID of the media to summarize
 * @param {string} param0.mediaName The original file name
 * @param {string} param0.style The style to use for the summary
 * @returns {Promise<void>}
 */
const publishSummarizeTextEvent = async ({ mediaId, mediaName, style }) => {
  const message = {
    type: EVENTS.SUMMARIZE_TEXT.type,
    payload: { mediaId, mediaName, style },
  };

  await publishEvent({
    topicArn: EVENTS.SUMMARIZE_TEXT.topicArn,
    message,
  });
};

module.exports = {
  publishEvent,
  publishDeleteMediaEvent,
  publishSummarizeMediaEvent,
  publishSummarizeTextEvent,
};
