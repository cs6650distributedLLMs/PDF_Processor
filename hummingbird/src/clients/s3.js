import { GetObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { Upload } from '@aws-sdk/lib-storage';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

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
        endpoint: 'http://s3.localhost.localstack.cloud:4566',
        region: 'us-west-2',
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

/**
 * Get a signed URL for a media object in S3.
 * @param {string} key S3 object key.
 * @return {Promise<string>} The signed URL.
 */
export const getMediaUrl = async (key) => {
  try {
    const client = new S3Client({
      endpoint: 'http://s3.localhost.localstack.cloud:4566',
      region: 'us-west-2',
    });

    const command = new GetObjectCommand({
      Bucket: 'media',
      Key: key,
    });

    const ONE_HOUR_IN_SECONDS = 3600;
    return await getSignedUrl(client, command, {
      expiresIn: ONE_HOUR_IN_SECONDS,
    });
  } catch (error) {
    console.log(error);
    throw error;
  }
};
