import {
  sendAcceptedResponse,
  sendOkResponse,
  sendErrorResponse,
} from '../core/responses.js';

export const uploadController = (req, res) => {
  try {
    sendAcceptedResponse(res, { id: 'todo' });
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
