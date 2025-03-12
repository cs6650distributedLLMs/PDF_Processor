import { sendBadRequestResponse } from '../core/responses.js';

const DEFAULT_MEDIA_SIZE = 500;
const MIN_MEDIA_SIZE = 100;
const MAX_MEDIA_SIZE = 1024;

/**
 * Extract additional configuration options from the request query string.
 * @param req
 * @param res
 * @param next
 * @returns void
 */
const extractMediaResizingOptions = (req, res, next) => {
  const { targetSize } = req.query;

  if (!validTargetSize(targetSize)) {
    sendBadRequestResponse(res, {
      message: `targetSize should be a value between ${MIN_MEDIA_SIZE} and ${MAX_MEDIA_SIZE}`,
    });
    return;
  }

  req.hummingbirdOptions = {
    ...req?.hummingbirdOptions,
    targetSize: targetSize ? parseInt(targetSize) : DEFAULT_MEDIA_SIZE,
  };

  next();
};

/**
 * Validates if the targetSize parameter is an integer and falls within the
 * expected values.
 * @param {any} targetSize targetSize parameter from the query string
 * @returns {boolean} whether the given value is valid
 */
const validTargetSize = (targetSize) => {
  if (!targetSize) {
    return true;
  }

  const intTargetSize = parseInt(targetSize, 10);

  if (isNaN(intTargetSize)) {
    return false;
  }

  return intTargetSize >= MIN_MEDIA_SIZE && intTargetSize <= MAX_MEDIA_SIZE;
};

export default extractMediaResizingOptions;
