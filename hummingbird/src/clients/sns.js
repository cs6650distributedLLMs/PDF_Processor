import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';

/**
 * Publishes an event to an SNS topic.
 * @param {object} param0 Function parameters
 * @param {string} param0.topicArn The ARN of the SNS topic to publish to
 * @param {object} param0.message The message to publish
 * @return {Promise<void>}
 */
export const publishEvent = async ({ topicArn, message }) => {
  try {
    const client = new SNSClient({
      endpoint: 'http://sns.localhost.localstack.cloud:4566',
      region: 'us-west-2',
    });

    const command = new PublishCommand({
      TopicArn: topicArn,
      Message: JSON.stringify(message),
    });

    await client.send(command);
  } catch (error) {
    console.log(error);
    throw error;
  }
};
