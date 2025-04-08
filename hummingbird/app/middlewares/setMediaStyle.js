const { SUMMARY_STYLE } = require('../core/constants.js');

const { DEFAULT_STYLE } = SUMMARY_STYLE;

/**
 * Extract additional configuration options from the request query string.
 * @param req
 * @param res
 * @param next
 * @returns void
 */
const middleware = (req, res, next) => {
  const { style: styleFromQs } = req.query;
  const { style: styleFromBody } = req.body;

  const style = styleFromQs || styleFromBody;

  req.hummingbirdOptions = {
    ...req?.hummingbirdOptions,
    style: style || DEFAULT_STYLE,
  };

  next();
};

module.exports = middleware;