const {
  DeleteObjectCommand,
  GetObjectCommand,
  ListObjectsV2Command,
  DeleteObjectsCommand,
  S3Client,
} = require('@aws-sdk/client-s3');
const { Upload } = require('@aws-sdk/lib-storage');
const { getLogger } = require('../logger.js');
const { BUCKETS } = require('../core/constants.js');

const logger = getLogger();

/**
 * Uploads a media file to S3.
 * @param {object} param0 Function parameters
 * @param {string} param0.mediaId The partial key to store the media under in S3
 * @param {string} param0.mediaName The name of the media file
 * @param {WritableStream|Buffer} param0.body The stream to read the media from
 * @param {string} param0.keyPrefix The prefix to use in the S3 key
 * @returns Promise<void>
 */
const uploadMediaToStorage = ({ mediaId, mediaName, body, keyPrefix }) => {
  try {
    const upload = new Upload({
      client: new S3Client({ region: process.env.AWS_REGION }),
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
 * Retrieves the media file from S3.
 * The media file is returned as a stream.
 * The full file is retrieved for post-processing.
 * @param {object} param0 Function parameters
 * @param {string} param0.mediaId The partial key to store the media under in S3
 * @param {string} param0.mediaName The name of the media file
 * @param {string} param0.keyPrefix The prefix to use in the S3 key
 * @returns {Promise<Uint8Array>} The media file stream
 */
const getMediaFile = async ({ mediaId, mediaName, keyPrefix }) => {
  try {
    const client = new S3Client({ region: process.env.AWS_REGION });

    const command = new GetObjectCommand({
      Bucket: process.env.MEDIA_BUCKET_NAME,
      Key: `${keyPrefix}/${mediaId}/${mediaName}`,
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
const deleteMediaFile = async ({ mediaId, mediaName, keyPrefix }) => {
  try {
    const client = new S3Client({ region: process.env.AWS_REGION });

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

const deleteMediaFolder = async ({ mediaId }) => {
  const client = new S3Client({ region: process.env.AWS_REGION });

  for (const keyPrefix of Object.values(BUCKETS)) {
    const basePrefix = `${keyPrefix}/${mediaId}/`;

    try {
      const listCommand = new ListObjectsV2Command({
        Bucket: process.env.MEDIA_BUCKET_NAME,
        Prefix: basePrefix,
      });

      const listed = await client.send(listCommand);

      if (!listed.Contents || listed.Contents.length === 0) continue;

      const deleteParams = {
        Bucket: process.env.MEDIA_BUCKET_NAME,
        Delete: { Objects: listed.Contents.map((obj) => ({ Key: obj.Key })) },
      };
      const deleteCommand = new DeleteObjectsCommand(deleteParams);
      await client.send(deleteCommand);
    } catch (error) {
      logger.error(`Error deleting folder ${basePrefix}`, error);
      throw error;
    }
  }
};

module.exports = {
  deleteMediaFile,
  deleteMediaFolder,
  getMediaFile,
  uploadMediaToStorage,
};
