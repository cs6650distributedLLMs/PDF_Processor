import { Router } from 'express';
import {
  deleteController,
  downloadController,
  getController,
  statusController,
  uploadController,
} from '../controllers/media.js';
import extractMediaResizingOptions from '../middlewares/extractMediaResizingOptions.js';

const router = Router();

router.post('/upload', extractMediaResizingOptions, uploadController);

router.get('/:id/status', statusController);

router.get('/:id/download', downloadController);

router.get('/:id', getController);

router.delete('/:id', deleteController);

export default router;
