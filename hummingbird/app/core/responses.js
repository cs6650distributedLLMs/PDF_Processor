export const sendOkResponse = (res, data) => {
  res.status(200).send(data);
};

export const sendAcceptedResponse = (res, data) => {
  res.status(202).send(data);
};

export const sendNoContentResponse = (res) => {
  res.status(204).send();
};

export const sendBadRequestResponse = (res, error) => {
  res.status(400).send({ message: error?.message || 'Bad request' });
};

export const sendNotFoundResponse = (res) => {
  res.status(404).send({ message: 'Not found' });
};

export const sendResponse = (res, status, message) => {
  res.status(status).send({ message });
};

export const sendErrorResponse = (res, error) => {
  res
    .status(error?.status || 500)
    .send(error?.message || 'Internal server error');
};
