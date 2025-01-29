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
  res.status(400).send(error.message || 'Bad request');
};

export const sendErrorResponse = (res, error) => {
  res
    .status(error.status || 500)
    .data(error.message || 'Internal server error');
};
