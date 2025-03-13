const { Span } = require('@opentelemetry/api');
const opentelemetry = require('@opentelemetry/api');
const { deleteMedia } = require('../clients/dynamodb.js');
const { deleteMediaFile } = require('../clients/s3.js');
const { MEDIA_STATUS } = require('../constants.js');
const { getLogger } = require('../logger');

const logger = getLogger();

/**
 * Delete media from storage.
 * @param {object} param0 The function parameters
 * @param {string} param0.mediaId The media ID for deletion
 * @param {Span} param0.span OpenTelemetry trace Span object
 * @returns {Promise<void>}
 */
const deleteMediaHandler = async ({ mediaId, span }) => {
  if (!mediaId) {
    logger.info('Skipping delete media message with no mediaId.');
    return;
  }

  logger.info(`Deleting media with id ${mediaId}.`);

  try {
    const { name: mediaName, status } = await deleteMedia(mediaId);

    if (!mediaName) {
      logger.info(`Media with id ${mediaId} not found.`);
      return;
    }

    await deleteMediaFile({ mediaId, mediaName });

    if (status !== MEDIA_STATUS.PROCESSING) {
      const keyPrefix = status === MEDIA_STATUS.ERROR ? 'uploads' : 'resized';
      await deleteMediaFile({
        mediaId,
        mediaName,
        keyPrefix,
      });
    }

    logger.info(`Deleted media with id ${mediaId}.`);
    span.setStatus({ code: opentelemetry.SpanStatusCode.OK });
  } catch (err) {
    span.setStatus({ code: opentelemetry.SpanStatusCode.ERROR });
    logger.error(`Error while deleting media with id ${mediaId}.`, err);
    span.end();
    throw err;
  }
};

module.exports = deleteMediaHandler;
