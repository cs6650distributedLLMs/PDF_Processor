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
    // The lambda function will be triggered automatically
    // EXTRACT_TEXT: {
    //   topicArn: process.env.MEDIA_MANAGEMENT_TOPIC_ARN,
    //   type: 'media.v1.extract.text',
    // },
    SUMMARIZE_TEXT: {
      topicArn: process.env.MEDIA_MANAGEMENT_TOPIC_ARN,
      type: 'media.v1.summarize.text',
    },
  },

  MEDIA_STATUS: {
    PENDING: 'PENDING',
    PROCESSING: 'PROCESSING',
    EXTRACTED: 'EXTRACTED',
    SUMMARIZED: 'SUMMARIZED',
    ERROR: 'ERROR',
  },

  SUMMARY_STYLE: {
    DEFAULT_STYLE: 'concise',
    VALID_STYLES: ['concise', 'detailed', 'bullet-points'],
  },

  BUCKETS: {
    UPLOADS: 'uploads',
    EXTRACTS: 'extracts',
    SUMMARIES: 'summaries',
  },
};
