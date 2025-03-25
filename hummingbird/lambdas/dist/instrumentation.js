const { NodeSDK } = require('@opentelemetry/sdk-node');
const { Resource } = require('@opentelemetry/resources');
const {
  getNodeAutoInstrumentations,
} = require('@opentelemetry/auto-instrumentations-node');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const {
  OTLPTraceExporter,
} = require('@opentelemetry/exporter-trace-otlp-proto');
const {
  OTLPMetricExporter,
} = require('@opentelemetry/exporter-metrics-otlp-proto');
const { ATTR_SERVICE_NAME } = require('@opentelemetry/semantic-conventions');
const {
  ATTR_DEPLOYMENT_ENVIRONMENT_NAME,
} = require('@opentelemetry/semantic-conventions/incubating');

const traceExporter = new OTLPTraceExporter();
const metricReader = new PeriodicExportingMetricReader({
  exporter: new OTLPMetricExporter(),
});

global.customInstrumentation = {
  traceExporter,
  metricReader,
};

const init = () => {
  const sdk = new NodeSDK({
    resource: new Resource({
      [ATTR_SERVICE_NAME]: process.env.AWS_LAMBDA_FUNCTION_NAME,
      [ATTR_DEPLOYMENT_ENVIRONMENT_NAME]: process.env.NODE_ENV,
    }),
    traceExporter,
    metricReader,
    instrumentations: [
      getNodeAutoInstrumentations({
        '@opentelemetry/instrumentation-aws-lambda': {
          enabled: true,
          disableAwsContextPropagation: true,
          requestHook: (span, { event, context }) => {
            span.setAttribute('faas.name', context.functionName);

            if (event.requestContext && event.requestContext.http) {
              span.setAttribute(
                'faas.http.method',
                event.requestContext.http.method
              );
              span.setAttribute(
                'faas.http.target',
                event.requestContext.http.path
              );
            }

            if (event.queryStringParameters)
              span.setAttribute(
                'faas.http.queryParams',
                JSON.stringify(event.queryStringParameters)
              );
          },
          responseHook: (span, { err, res }) => {
            if (err instanceof Error)
              span.setAttribute('faas.error', err.message);
            if (res) {
              span.setAttribute('faas.http.status_code', res.statusCode);
            }
          },
        },
      }),
    ],
  });

  sdk.start();
  console.log('OpenTelemetry SDK started');

  process.on('SIGTERM', () => {
    sdk
      .shutdown()
      .then(() => process.exit(0))
      .catch((err) => {
        console.error('Error shutting down OpenTelemetry SDK', err);
        process.exit(1);
      });
  });
};

init();
