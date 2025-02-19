export const MAX_FILE_SIZE = 100 * 1024 * 1024; // 100 MB

export const CUSTOM_FORMIDABLE_ERRORS = {
  INVALID_FILE_TYPE: {
    code: 9000,
    httpCode: 400,
  },
};

export const EVENTS = {
  DELETE_MEDIA: {
    topicArn: process.env.MEDIA_MANAGEMENT_TOPIC_ARN,
    type: 'media.v1.delete',
  },
};

export const MEDIA_STATUS = {
  PENDING: 'PENDING',
  PROCESSING: 'PROCESSING',
  COMPLETE: 'COMPLETE',
  ERROR: 'ERROR',
};
