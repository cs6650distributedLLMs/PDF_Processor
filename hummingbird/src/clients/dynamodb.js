import {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
  UpdateItemCommand,
} from '@aws-sdk/client-dynamodb';
import { isLocalEnv } from '../core/utils.js';
import { MEDIA_STATUS } from '../core/constants.js';

const endpoint = isLocalEnv()
  ? 'http://dynamodb.localhost.localstack.cloud:4566'
  : undefined;

/**
 * Stores metadata about a media object in DynamoDB.
 * @param {object} param0 Media metadata
 * @param {string} param0.mediaId The media ID.
 * @param {number} param0.size The size of the media object in bytes
 * @param {string} param0.name The original filename of the media object
 * @param {string} param0.mimetype The MIME type of the media object
 * @return {Promise<void>}
 */
export const createMedia = async ({ mediaId, size, name, mimetype }) => {
  const TableName = process.env.MEDIA_DYNAMODB_TABLE_NAME;
  const command = new PutItemCommand({
    TableName,
    Item: {
      PK: { S: `MEDIA#${mediaId}` },
      SK: { S: 'METADATA' },
      size: { N: size.toString() },
      name: { S: name },
      mimetype: { S: mimetype },
      status: { S: MEDIA_STATUS.PENDING },
    },
  });

  try {
    const client = new DynamoDBClient({
      endpoint,
      region: process.env.AWS_REGION,
    });

    await client.send(command);
  } catch (error) {
    console.log(error);
    throw error;
  }
};

/**
 * Gets metadata about a media object from DynamoDB.
 * @param {string} mediaId The media ID.
 * @return {Promise<object>} The media object metadata.
 */
export const getMedia = async (mediaId) => {
  const TableName = process.env.MEDIA_DYNAMODB_TABLE_NAME;
  const command = new GetItemCommand({
    TableName,
    Key: {
      PK: { S: `MEDIA#${mediaId}` },
      SK: { S: 'METADATA' },
    },
  });

  try {
    const client = new DynamoDBClient({
      endpoint,
      region: process.env.AWS_REGION,
    });

    const { Item } = await client.send(command);

    if (!Item) {
      return null;
    }

    return {
      mediaId,
      size: Number(Item.size.N),
      name: Item.name.S,
      mimetype: Item.mimetype.S,
      status: Item.status.S,
    };
  } catch (error) {
    console.log(error);
    throw error;
  }
};

/**
 * Conditionally updates the status of a media object in DynamoDB.
 * @param {object} param0 The media object key
 * @param {string} param0.mediaId The media ID
 * @param {string} param0.newStatus The new status to set
 * @param {string} param0.expectedCurrentStatus The expected current status
 * @return {Promise<object>}
 */
export const setMediaStatusConditionally = async ({
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
  });

  try {
    const client = new DynamoDBClient({
      endpoint,
      region: process.env.AWS_REGION,
    });

    return await client.send(command);
  } catch (error) {
    console.log(error);
    throw error;
  }
};

/**
 * Updates the status of a media object in DynamoDB.
 * @param {object} param0 Function parameters
 * @param {string} param0.mediaId The media ID
 * @param {string} param0.newStatus The new status to set
 * @return {Promise<object>}
 */
export const setMediaStatus = async ({ mediaId, newStatus }) => {
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
    const client = new DynamoDBClient({
      endpoint,
      region: process.env.AWS_REGION,
    });

    return await client.send(command);
  } catch (error) {
    console.log(error);
    throw error;
  }
};
