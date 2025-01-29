import { Router } from 'express';
import {
  deleteController,
  downloadController,
  getController,
  uploadController,
} from '../controllers/media.js';

const router = Router();

router.post('/upload', uploadController);

router.get('/:id/download', downloadController);

router.get('/:id', getController);

router.delete('/:id', deleteController);

export default router;
