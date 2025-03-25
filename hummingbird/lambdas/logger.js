const logsAPI = require('@opentelemetry/api-logs');
const {
  LoggerProvider,
  SimpleLogRecordProcessor,
} = require('@opentelemetry/sdk-logs');
const { OTLPLogExporter } = require('@opentelemetry/exporter-logs-otlp-http');
const {
  OpenTelemetryTransportV3,
} = require('@opentelemetry/winston-transport');
const { Resource } = require('@opentelemetry/resources');
const winston = require('winston');

const { combine, errors, json, metadata, timestamp } = winston.format;

/**
 * Logger instance.
 * @type {winston.Logger}
 */
let logger;

/**
 * Initialize the logger.
 * @returns {void}
 */
const init = ({ service = 'hummingbird' } = {}) => {
  const loggerProvider = new LoggerProvider({
    resource: new Resource({
      'service.name': service,
      'service.version': '1.0.0',
      'deployment.environment': process.env.NODE_ENV || 'development',
    }),
  });

  const otlpExporter = new OTLPLogExporter();

  loggerProvider.addLogRecordProcessor(
    new SimpleLogRecordProcessor(otlpExporter)
  );

  logsAPI.logs.setGlobalLoggerProvider(loggerProvider);

  logger = winston.createLogger({
    level: 'info',
    format: combine(timestamp(), errors({ stack: true }), metadata(), json()),
    defaultMeta: {
      service,
      environment: process.env.NODE_ENV || 'development',
    },
    transports: [
      new winston.transports.Console(),
      new OpenTelemetryTransportV3({
        loggerProvider,
        logAttributes: {
          'service.name': service,
          'deployment.environment': process.env.NODE_ENV || 'development',
        },
      }),
    ],
  });
};

/**
 * Get the logger instance.
 * @returns {winston.Logger}
 */
const getLogger = () => {
  if (!logger) {
    init();
  }

  return logger;
};

module.exports = { init, getLogger };
