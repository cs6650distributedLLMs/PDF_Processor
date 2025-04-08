const { sendBadRequestResponse } = require('../core/responses.js');
const { SUMMARY_STYLE } = require('../core/constants.js');

const { VALID_STYLES } = SUMMARY_STYLE;

/**
 * Validate the summary style option from the query string or request body.
 * @param req
 * @param res
 * @param next
 * @returns void
 */
const middleware = (req, res, next) => {
  const { style: styleFromQs } = req.query;
  const { style: styleFromBody } = req.body;

  const style = styleFromQs || styleFromBody;

  if (!validSummaryStyle(style)) {
    sendBadRequestResponse(res, {
      message: `style should be one of: ${VALID_STYLES.join(', ')}`,
    });
    return;
  }

  next();
};

/**
 * Validates if the style parameter is one of the valid styles
 * @param {any} style style parameter from the query string
 * @returns {boolean} whether the given value is valid
 */
const validSummaryStyle = (style) => {
  if (!style) {
    return true;
  }

  return VALID_STYLES.includes(style);
};

module.exports = middleware;