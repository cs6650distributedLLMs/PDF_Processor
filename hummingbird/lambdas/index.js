const { handler: manageMedia } = require('./functions/manageMedia.js');
const {
  handler: processMediaUpload,
} = require('./functions/processMediaUpload.js');

const handlers = {
  manageMedia,
  processMediaUpload,
};

module.exports = { handlers };
