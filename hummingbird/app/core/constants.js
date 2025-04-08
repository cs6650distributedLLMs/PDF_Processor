module.exports = {
  MAX_FILE_SIZE: 100 * 1024 * 1024, // 100 MB

  CUSTOM_FORMIDABLE_ERRORS: {
    INVALID_FILE_TYPE: {
      code: 9000,
      httpCode: 400,
    },
  },

  EVENTS: {
    DELETE_MEDIA: {
      topicArn: process.env.MEDIA_MANAGEMENT_TOPIC_ARN,
      type: 'media.v1.delete',
    },
    SUMMARIZE_MEDIA: {
      topicArn: process.env.MEDIA_MANAGEMENT_TOPIC_ARN,
      type: 'media.v1.summarize',
    },
    SUMMARIZE_TEXT: {
      topicArn: process.env.MEDIA_MANAGEMENT_TOPIC_ARN,
      type: 'media.v1.summarize.text',
    },
  },

  MEDIA_STATUS: {
    PENDING: 'PENDING',
    PROCESSING: 'PROCESSING',
    COMPLETE: 'COMPLETE',
    ERROR: 'ERROR',
  },

  SUMMARY_STYLE: {
    DEFAULT_STYLE: 'concise',
    VALID_STYLES: ['concise', 'detailed', 'bullet-points'],
  },
};