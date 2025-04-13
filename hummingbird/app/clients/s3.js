const {
  DeleteObjectCommand,
  GetObjectCommand,
  S3Client,
} = require('@aws-sdk/client-s3');
const { Upload } = require('@aws-sdk/lib-storage');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { isLocalEnv, getBaseName } = require('../core/utils.js');
const { getLogger } = require('../logger.js');
const { BUCKETS } = require('../core/constants.js');

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
 * @returns Promise<CompleteMultipartUploadCommandOutput>
 */
const uploadMediaToStorage = ({
  mediaId,
  mediaName,
  body,
  keyPrefix = BUCKETS.UPLOADS,
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
 * @returns {Promise<string>} The signed URL.
 */
const getProcessedMediaUrl = async ({ mediaId, mediaName }) => {
  try {
    const client = new S3Client({
      endpoint,
      region: process.env.AWS_REGION,
    });

    const basename = getBaseName(mediaName);
    const summaryName = `${basename}.summary.txt`;

    const command = new GetObjectCommand({
      Bucket: process.env.MEDIA_BUCKET_NAME,
      Key: `${BUCKETS.SUMMARIES}/${mediaId}/${summaryName}`,
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
 * @returns {Promise<Uint8Array>} The media file stream
 */
const getMediaFile = async ({ mediaId, mediaName }) => {
  try {
    const client = new S3Client({
      endpoint,
      region: process.env.AWS_REGION,
    });

    const command = new GetObjectCommand({
      Bucket: process.env.MEDIA_BUCKET_NAME,
      Key: `${BUCKETS.UPLOADS}/${mediaId}/${mediaName}`,
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
 * @returns {Promise<void>}
 */
const deleteMediaFile = async ({
  mediaId,
  mediaName,
  keyPrefix = BUCKETS.UPLOADS,
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

module.exports = {
  uploadMediaToStorage,
  getProcessedMediaUrl,
  getMediaFile,
  deleteMediaFile,
};
