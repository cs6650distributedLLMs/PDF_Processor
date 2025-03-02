import { NodeSDK } from '@opentelemetry/sdk-node';
import { Resource } from '@opentelemetry/resources';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-proto';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-proto';
import { ATTR_SERVICE_NAME } from '@opentelemetry/semantic-conventions';
import { ATTR_DEPLOYMENT_ENVIRONMENT_NAME } from '@opentelemetry/semantic-conventions/incubating';

import { diag, DiagConsoleLogger, DiagLogLevel } from '@opentelemetry/api';

export const init = () => {
  diag.setLogger(new DiagConsoleLogger(), DiagLogLevel.INFO);

  const sdk = new NodeSDK({
    resource: new Resource({
      [ATTR_SERVICE_NAME]: 'hummingbird',
      [ATTR_DEPLOYMENT_ENVIRONMENT_NAME]: process.env.NODE_ENV,
    }),
    traceExporter: new OTLPTraceExporter(),
    metricReader: new PeriodicExportingMetricReader({
      exporter: new OTLPMetricExporter(),
    }),
    instrumentations: [getNodeAutoInstrumentations()],
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
