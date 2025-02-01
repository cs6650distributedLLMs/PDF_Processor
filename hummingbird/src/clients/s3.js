import { S3Client } from '@aws-sdk/client-s3';
import { Upload } from '@aws-sdk/lib-storage';

/**
 * Uploads a media file to S3.
 * @param {object} param0 Function parameters
 * @param {string} param0.key The key to store the media under in S3
 * @param {WritableStream} param0.writeStream The stream to read the media from
 * @return void
 */
export const uploadMediaToS3 = ({ key, writeStream }) => {
  try {
    const upload = new Upload({
      client: new S3Client({
        endpoint: 'http://localhost:4566',
        region: 'us-west-2',
        forcePathStyle: true,
      }),
      params: {
        Bucket: 'media',
        Key: key,
        Body: writeStream,
      },
    });

    return upload.done();
  } catch (error) {
    console.log(error);
    throw error;
  }
};
