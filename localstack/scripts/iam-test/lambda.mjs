import {
  DynamoDBClient,
  PutItemCommand
} from '@aws-sdk/client-dynamodb';

export const handler = async (event) => {
  const command = new PutItemCommand({
    TableName: 'test-dynamo-table',
    Item: {
      PK: { S: 'PK' },
      SK: { S: 'SK' }
    },
  });

  const client = new DynamoDBClient({
    endpoint: 'http://dynamodb.localhost.localstack.cloud:4566',
    region: 'us-west-2'
  });

  try {
    const response = await client.send(command);

    return {
      statusCode: response.$metadata.statusCode,
      message: response.$metadata.message
    }
  } catch(error) {
    console.error(error);
  }
}
