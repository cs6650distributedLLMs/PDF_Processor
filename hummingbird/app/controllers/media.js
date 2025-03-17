const { errors: formidableErrors } = require('formidable');
const {
  sendAcceptedResponse,
  sendOkResponse,
  sendErrorResponse,
  sendResponse,
  sendBadRequestResponse,
  sendNotFoundResponse,
} = require('../core/responses.js');
const { uploadMedia } = require('../actions/uploadMedia.js');
const { convertBytesToMb } = require('../core/utils.js');
const {
  MAX_FILE_SIZE,
  CUSTOM_FORMIDABLE_ERRORS,
  MEDIA_STATUS,
} = require('../core/constants.js');
const { getProcessedMediaUrl } = require('../clients/s3.js');
const { createMedia, getMedia } = require('../clients/dynamodb.js');
const { getLogger } = require('../logger.js');
const {
  publishDeleteMediaEvent,
  publishResizeMediaEvent,
} = require('../clients/sns.js');

const logger = getLogger();

const uploadController = async (req, res) => {
  try {
    const { mediaId, file } = await uploadMedia(req);
    const { size, originalFilename: name, mimetype } = file;
    const { width } = req.hummingbirdOptions;

    await createMedia({ mediaId, size, name, mimetype, width });

    sendAcceptedResponse(res, { mediaId });
  } catch (error) {
    if (error.httpCode && error.code) {
      if (error.code === formidableErrors.biggerThanTotalMaxFileSize) {
        const maxFileSize = convertBytesToMb(MAX_FILE_SIZE);
        let message = `Failed to upload media. Check the file size. Max size is ${maxFileSize} MB.`;
        sendResponse(res, error.httpCode, message);
        return;
      }

      if (error.code === formidableErrors.maxFilesExceeded) {
        sendBadRequestResponse(res, {
          message:
            'Too many fields in the form. Only single file uploads are supported.',
        });
        return;
      }

      if (error.code === formidableErrors.malformedMultipart) {
        sendBadRequestResponse(res, {
          message: 'Malformed multipart form data.',
        });
        return;
      }

      if (error.code === CUSTOM_FORMIDABLE_ERRORS.INVALID_FILE_TYPE.code) {
        sendResponse(
          res,
          CUSTOM_FORMIDABLE_ERRORS.INVALID_FILE_TYPE.httpCode,
          'Invalid file type. Only images are supported.'
        );
        return;
      }

      sendBadRequestResponse(res);
      return;
    }

    logger.error(error);
    sendErrorResponse(res);
  }
};

const statusController = async (req, res) => {
  try {
    const mediaId = req.params.id;
    const media = await getMedia(mediaId);

    if (!media) {
      sendNotFoundResponse(res);
      return;
    }

    sendOkResponse(res, { status: media.status });
  } catch (error) {
    logger.error(error);
    sendErrorResponse(res);
  }
};

const downloadController = async (req, res) => {
  try {
    const mediaId = req.params.id;

    const media = await getMedia(mediaId);
    if (!media) {
      sendNotFoundResponse(res);
      return;
    }

    if (media.status !== MEDIA_STATUS.COMPLETE) {
      const SIXTY_SECONDS = 60;
      res.set('Retry-After', SIXTY_SECONDS);
      res.set('Location', `${req.hostname}/v1/media/${mediaId}/status`);
      sendAcceptedResponse(res, {
        message: 'Media processing in progress.',
      });
      return;
    }

    const url = await getProcessedMediaUrl({ mediaId, mediaName: media.name });

    res.redirect(302, url);
  } catch (error) {
    logger.error(error);
    sendErrorResponse(res);
  }
};

const getController = async (req, res) => {
  try {
    const mediaId = req.params.id;
    const media = await getMedia(mediaId);

    if (!media) {
      sendNotFoundResponse(res);
      return;
    }

    sendOkResponse(res, media);
  } catch (error) {
    logger.error(error);
    sendErrorResponse(res);
  }
};

const resizeController = async (req, res) => {
  try {
    const mediaId = req.params.id;

    const media = await getMedia(mediaId);
    if (!media) {
      sendNotFoundResponse(res);
      return;
    }

    const { width } = req.hummingbirdOptions;

    await publishResizeMediaEvent({ mediaId, width });

    sendAcceptedResponse(res, { mediaId });
  } catch (error) {
    logger.error(error);
    sendErrorResponse(res);
  }
};

const deleteController = async (req, res) => {
  try {
    const mediaId = req.params.id;

    const media = await getMedia(mediaId);
    if (!media) {
      sendNotFoundResponse(res);
      return;
    }

    await publishDeleteMediaEvent(mediaId);

    sendAcceptedResponse(res, { mediaId });
  } catch (error) {
    logger.error(error);
    sendErrorResponse(res);
  }
};

module.exports = {
  uploadController,
  statusController,
  downloadController,
  getController,
  resizeController,
  deleteController,
};
