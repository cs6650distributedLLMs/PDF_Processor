const express = require('express');
const {
  uploadController,
  statusController,
  downloadController,
  getController,
  summarizeController,
  deleteController,
} = require('../controllers/media.js');
const validateStyle = require('../middlewares/validateStyle.js');
const setMediaStyle = require('../middlewares/setMediaStyle.js');

const router = express.Router();

// Upload a new PDF
router.post('/', validateStyle, setMediaStyle, uploadController);

// Get media status
router.get('/:id/status', statusController);

// Download the summarized PDF
router.get('/:id/download', downloadController);

// Get media metadata
router.get('/:id', getController);

// Request to summarize a PDF with a specific style
router.post('/:id/summarize', validateStyle, setMediaStyle, summarizeController);

// Delete a media
router.delete('/:id', deleteController);

module.exports = router;