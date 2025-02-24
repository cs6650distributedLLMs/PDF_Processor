const {
  DeleteItemCommand,
  DynamoDBClient,
  UpdateItemCommand,
} = require('@aws-sdk/client-dynamodb');
const { getLogger } = require('../logger.js');

const logger = getLogger();

/**
 * Conditionally updates the status of a media object in DynamoDB.
 * @param {object} param0 The media object key
 * @param {string} param0.mediaId The media ID
 * @param {string} param0.newStatus The new status to set
 * @param {string} param0.expectedCurrentStatus The expected current status
 * @return {Promise<object>}
 */
const setMediaStatusConditionally = async ({
  mediaId,
  newStatus,
  expectedCurrentStatus,
}) => {
  const TableName = process.env.MEDIA_DYNAMODB_TABLE_NAME;
  const command = new UpdateItemCommand({
    TableName,
    Key: {
      PK: { S: `MEDIA#${mediaId}` },
      SK: { S: 'METADATA' },
    },
    UpdateExpression: 'SET #status = :newStatus',
    ConditionExpression: '#status = :expectedCurrentStatus',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: {
      ':newStatus': { S: newStatus },
      ':expectedCurrentStatus': { S: expectedCurrentStatus },
    },
    ReturnValues: 'ALL_NEW',
  });

  try {
    const client = new DynamoDBClient({ region: process.env.AWS_REGION });

    const { Attributes } = await client.send(command);

    if (!Attributes) {
      return null;
    }

    return {
      name: Attributes.name.S,
    };
  } catch (error) {
    logger.error(error);
    throw error;
  }
};

/**
 * Updates the status of a media object in DynamoDB.
 * @param {object} param0 Function parameters
 * @param {string} param0.mediaId The media ID
 * @param {string} param0.newStatus The new status to set
 * @return {Promise<void>}
 */
const setMediaStatus = async ({ mediaId, newStatus }) => {
  const TableName = process.env.MEDIA_DYNAMODB_TABLE_NAME;
  const command = new UpdateItemCommand({
    TableName,
    Key: {
      PK: { S: `MEDIA#${mediaId}` },
      SK: { S: 'METADATA' },
    },
    UpdateExpression: 'SET #status = :newStatus',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: { ':newStatus': { S: newStatus } },
  });

  try {
    const client = new DynamoDBClient({ region: process.env.AWS_REGION });

    await client.send(command);
  } catch (error) {
    logger.error(error);
    throw error;
  }
};

/**
 * Deletes the media object metadata from DynamoDB.
 * @param {string} mediaId The media ID
 * @return {Promise<object>}
 */
const deleteMedia = async (mediaId) => {
  const TableName = process.env.MEDIA_DYNAMODB_TABLE_NAME;
  const command = new DeleteItemCommand({
    TableName,
    Key: {
      PK: { S: `MEDIA#${mediaId}` },
      SK: { S: 'METADATA' },
    },
    ReturnValues: 'ALL_OLD',
  });

  try {
    const client = new DynamoDBClient({ region: process.env.AWS_REGION });

    const { Attributes } = await client.send(command);

    if (!Attributes) {
      return null;
    }

    return {
      name: Attributes.name.S,
      status: Attributes.status.S,
    };
  } catch (error) {
    logger.error(error);
    throw error;
  }
};

module.exports = {
  deleteMedia,
  setMediaStatus,
  setMediaStatusConditionally,
};
