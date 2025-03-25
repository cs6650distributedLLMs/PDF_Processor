const opentelemetry = require('@opentelemetry/api');

const meter = opentelemetry.metrics.getMeter(
  'hummingbird-async-media-processing-lambda'
);

const successesCounter = meter.createCounter('media.async.process.success', {
  description: 'Count of successfully processed media files',
});
const failuresCounter = meter.createCounter('media.async.process.failure', {
  description: 'Count of failed processed media files',
});

module.exports = {
  successesCounter,
  failuresCounter,
};
