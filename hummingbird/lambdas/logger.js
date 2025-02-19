import winston from 'winston';

const { combine, json, timestamp } = winston.format;

/**
 * Logger instance.
 * @type {winston.Logger}
 */
let logger;

/**
 * Initialize the logger.
 * @return {void}
 */
export const init = ({ service = 'hummingbird' } = {}) => {
  logger = winston.createLogger({
    level: 'info',
    format: combine(timestamp(), json()),
    defaultMeta: { service },
    transports: [new winston.transports.Console()],
  });
};

/**
 * Get the logger instance.
 * @returns {winston.Logger}
 */
export const getLogger = () => {
  if (!logger) {
    init();
  }

  return logger;
};
