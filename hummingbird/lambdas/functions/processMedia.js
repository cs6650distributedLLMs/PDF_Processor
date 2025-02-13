import { S3Client, HeadObjectCommand } from '@aws-sdk/client-s3';
import { withLogging } from '../common.js';

const client = new S3Client();

const getHandler = () => {
  return async (event, context) => {
    const bucket = event.Records[0].s3.bucket.name;
    const key = decodeURIComponent(event.Records[0].s3.object.key);

    try {
      const { ContentType } = await client.send(
        new HeadObjectCommand({
          Bucket: bucket,
          Key: key,
        })
      );

      console.log('CONTENT TYPE:', ContentType);
      return ContentType;
    } catch (err) {
      console.log(err);
      const message = `Error getting object ${key} from bucket ${bucket}.`;
      console.log(message);
      throw new Error(message);
    }
  };
};

export const handler = withLogging(getHandler());
