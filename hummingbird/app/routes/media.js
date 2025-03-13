import { Router } from 'express';
import {
  deleteController,
  downloadController,
  getController,
  resizeController,
  statusController,
  uploadController,
} from '../controllers/media.js';
import setMediaWidth from '../middlewares/setMediaWidth.js';
import validateWidth from '../middlewares/validateWidth.js';

const router = Router();

router.post('/upload', validateWidth, setMediaWidth, uploadController);

router.get('/:id/status', statusController);

router.get('/:id/download', downloadController);

router.get('/:id', getController);

router.put('/:id/resize', validateWidth, setMediaWidth, resizeController);

router.delete('/:id', deleteController);

export default router;
