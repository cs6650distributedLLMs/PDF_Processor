import {
  DeleteObjectCommand,
  GetObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { Upload } from '@aws-sdk/lib-storage';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { isLocalEnv } from '../core/utils.js';
import { getLogger } from '../logger.js';

const logger = getLogger();

const endpoint = isLocalEnv()
  ? 'http://s3.localhost.localstack.cloud:4566'
  : undefined;

/**
 * Uploads a media file to S3.
 * @param {object} param0 Function parameters
 * @param {string} param0.mediaId The partial key to store the media under in S3
 * @param {string} param0.mediaName The name of the media file
 * @param {WritableStream|Buffer} param0.writeStream The stream to read the media from
 * @param {string} param0.keyPrefix The prefix to use in the S3 key
 * @return Promise<CompleteMultipartUploadCommandOutput>
 */
export const uploadMediaToStorage = ({
  mediaId,
  mediaName,
  body,
  keyPrefix = 'uploads',
}) => {
  try {
    const upload = new Upload({
      client: new S3Client({
        endpoint,
        region: process.env.AWS_REGION,
      }),
      params: {
        Bucket: process.env.MEDIA_BUCKET_NAME,
        Key: `${keyPrefix}/${mediaId}/${mediaName}`,
        Body: body,
      },
    });

    return upload.done();
  } catch (error) {
    logger.error(error);
    throw error;
  }
};

/**
 * Get a signed URL for a media object in S3.
 * @param {object} param0 Function parameters
 * @param {string} param0.mediaId The partial key to store the media under in S3
 * @param {string} param0.mediaName The name of the media file
 * @return {Promise<string>} The signed URL.
 */
export const getProcessedMediaUrl = async ({ mediaId, mediaName }) => {
  try {
    const client = new S3Client({
      endpoint,
      region: process.env.AWS_REGION,
    });

    const command = new GetObjectCommand({
      Bucket: process.env.MEDIA_BUCKET_NAME,
      Key: `resized/${mediaId}/${mediaName}`,
    });

    const ONE_HOUR_IN_SECONDS = 3600;
    return await getSignedUrl(client, command, {
      expiresIn: ONE_HOUR_IN_SECONDS,
    });
  } catch (error) {
    logger.error(error);
    throw error;
  }
};

/**
 * Retrieves the media file from S3.
 * The media file is returned as a stream.
 * The full file is retrieved for post-processing.
 * @param {object} param0 Function parameters
 * @param {string} param0.mediaId The partial key to store the media under in S3
 * @param {string} param0.mediaName The name of the media file
 * @return {Promise<Uint8Array>} The media file stream
 */
export const getMediaFile = async ({ mediaId, mediaName }) => {
  try {
    const client = new S3Client({
      endpoint,
      region: process.env.AWS_REGION,
    });

    const command = new GetObjectCommand({
      Bucket: process.env.MEDIA_BUCKET_NAME,
      Key: `uploads/${mediaId}/${mediaName}`,
    });

    const response = await client.send(command);
    return response.Body.transformToByteArray();
  } catch (error) {
    logger.error(error);
    throw error;
  }
};

/**
 * Deletes a media file from S3.
 * @param {object} param0 Function parameters
 * @param {string} param0.mediaId The partial key to store the media under in S3
 * @param {string} param0.mediaName The name of the media file
 * @param {string} param0.keyPrefix The prefix to use in the S3 key
 * @return {Promise<void>}
 */
export const deleteMediaFile = async ({
  mediaId,
  mediaName,
  keyPrefix = 'uploads',
}) => {
  try {
    const client = new S3Client({
      endpoint,
      region: process.env.AWS_REGION,
    });

    const command = new DeleteObjectCommand({
      Bucket: process.env.MEDIA_BUCKET_NAME,
      Key: `${keyPrefix}/${mediaId}/${mediaName}`,
    });

    await client.send(command);
  } catch (error) {
    logger.error(error);
    throw error;
  }
};
