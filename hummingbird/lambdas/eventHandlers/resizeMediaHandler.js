const sharp = require('sharp');
const { ConditionalCheckFailedException } = require('@aws-sdk/client-dynamodb');
const { getLogger } = require('../logger');
const { setMediaStatusConditionally } = require('../clients/dynamodb.js');
const { getMediaFile, uploadMediaToStorage } = require('../clients/s3.js');
const { MEDIA_STATUS } = require('../constants.js');
const { setMediaStatus } = require('../clients/dynamodb');

const logger = getLogger();

/**
 * Resize a media file to the specified width.
 * @param {string} mediaId The media ID for resizing
 * @param {number} width The width to resize the media to
 * @returns {Promise<void>}
 */
const resizeMediaHandler = async ({ mediaId, width }) => {
  if (!mediaId || !width) {
    logger.info('Skipping resize media message with missing mediaId or width.');
    return;
  }

  logger.info(`Resizing media with id ${mediaId} to ${width} pixels.`);

  try {
    const { name: mediaName } = await setMediaStatusConditionally({
      mediaId,
      newStatus: MEDIA_STATUS.PROCESSING,
      expectedCurrentStatus: MEDIA_STATUS.COMPLETE,
    });

    logger.info('Media status set to PROCESSING');

    const image = await getMediaFile({ mediaId, mediaName });

    logger.info('Got media file');

    const resizedImage = await resizeImageWithSharp({
      imageBuffer: image,
      width,
    });

    logger.info('Resized media');

    await uploadMediaToStorage({
      mediaId,
      mediaName,
      body: resizedImage,
      keyPrefix: 'resized',
    });

    logger.info('Uploaded resized media');

    await setMediaStatusConditionally({
      mediaId,
      newStatus: MEDIA_STATUS.COMPLETE,
      expectedCurrentStatus: MEDIA_STATUS.PROCESSING,
    });

    logger.info(`Resized media ${mediaId}.`);
  } catch (err) {
    if (err instanceof ConditionalCheckFailedException) {
      logger.error(
        `Media ${mediaId} not found or status is not ${MEDIA_STATUS.PROCESSING}.`
      );
      throw err;
    }

    await setMediaStatus({
      mediaId,
      newStatus: MEDIA_STATUS.ERROR,
    });

    logger.error(`Failed to resize media ${mediaId}`, err);
    throw err;
  }
};

/**
 * Resizes an image to a specific width and converts it to JPEG format.
 * @param {object} param0 The function parameters
 * @param {Uint8Array} param0.imageBuffer The image buffer to resize
 * @param {string} width The size to resize the uploaded image to
 * @returns {Promise<Buffer>} The resized image buffer
 */
const resizeImageWithSharp = async ({ imageBuffer, width }) => {
  const imageSizePx = parseInt(width);
  return await sharp(imageBuffer)
    .resize(imageSizePx)
    .toFormat('jpeg')
    .toBuffer();
};

module.exports = resizeMediaHandler;
