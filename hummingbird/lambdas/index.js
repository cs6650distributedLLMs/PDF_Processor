const { handler: deleteMedia } = require('./functions/deleteMedia.js');
const { handler: processMedia } = require('./functions/processMedia.js');

const handlers = {
  deleteMedia,
  processMedia,
};

module.exports = { handlers };
