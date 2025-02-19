import sharp from 'sharp';
import { getMediaId, withLogging } from '../common.js';
import {
  setMediaStatus,
  setMediaStatusConditionally,
} from '../../app/clients/dynamodb.js';
import { getMediaFile, uploadMediaToStorage } from '../../app/clients/s3.js';
import { MEDIA_STATUS } from '../../app/core/constants.js';

/**
 * Gets the handler for the processMedia Lambda function.
 * @return {Function} The Lambda function handler
 * @see https://docs.aws.amazon.com/lambda/latest/dg/nodejs-handler.html
 */
const getHandler = () => {
  /**
   * Processes a media file uploaded to S3.
   * @param {object} event The S3 event object
   * @param {object} context The Lambda execution context
   * @return {Promise<void>}
   */
  return async (event, context) => {
    const mediaId = getMediaId(event.Records[0].s3.object.key);

    try {
      await setMediaStatusConditionally({
        mediaId,
        newStatus: MEDIA_STATUS.PROCESSING,
        expectedCurrentStatus: MEDIA_STATUS.PENDING,
      });

      const image = await getMediaFile(mediaId);
      const resizedImage = await resizeImage(image);

      await uploadMediaToStorage({
        mediaId,
        body: resizedImage,
        keyPrefix: 'resized',
      });

      await setMediaStatusConditionally({
        mediaId,
        newStatus: MEDIA_STATUS.COMPLETE,
        expectedCurrentStatus: MEDIA_STATUS.PROCESSING,
      });

      console.log(`Resized image ${mediaId}.`);
    } catch (err) {
      if (err instanceof ConditionalCheckFailedException) {
        console.log(
          `Media ${mediaId} not found or status is not ${MEDIA_STATUS.PROCESSING}.`
        );
        return;
      }

      await setMediaStatus({
        mediaId,
        newStatus: MEDIA_STATUS.ERROR,
      });

      console.log(err);
      throw err;
    }
  };
};

/**
 * Resizes an image to a specific width and converts it to JPEG format.
 * @param {Uint8Array} imageBuffer The image buffer to resize
 * @return {Promise<Buffer>} The resized image buffer
 */
const resizeImage = async (imageBuffer) => {
  const IMAGE_WIDTH_PX = 500;
  return await sharp(imageBuffer)
    .resize(IMAGE_WIDTH_PX)
    .toFormat('jpeg')
    .toBuffer();
};

export const handler = withLogging(getHandler());
