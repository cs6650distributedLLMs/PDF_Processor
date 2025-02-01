import {
  sendAcceptedResponse,
  sendOkResponse,
  sendErrorResponse,
} from '../core/responses.js';
import { uploadMedia } from '../actions/uploadMedia.js';

export const uploadController = async (req, res) => {
  try {
    const fileId = await uploadMedia(req);

    sendAcceptedResponse(res, { fileId });
  } catch (error) {
    sendErrorResponse(res, error);
  }
};

export const downloadController = (req, res) => {
  try {
    sendOkResponse(res, { id: 'todo' });
  } catch (error) {
    sendErrorResponse(res, error);
  }
};

export const getController = (req, res) => {
  try {
    sendOkResponse(res, { id: 'todo' });
  } catch (error) {
    sendErrorResponse(res, error);
  }
};

export const deleteController = (req, res) => {
  try {
    sendAcceptedResponse(res, { id: 'todo' });
  } catch (error) {
    sendErrorResponse(res, error);
  }
};
