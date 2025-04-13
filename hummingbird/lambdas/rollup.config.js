const { nodeResolve } = require('@rollup/plugin-node-resolve');
const commonjs = require('@rollup/plugin-commonjs');
const json = require('@rollup/plugin-json');

module.exports = {
  input: './index.js',
  output: {
    file: 'dist/index.js',
    compact: true,
    format: 'cjs',
    inlineDynamicImports: true,
  },
  plugins: [json(), nodeResolve({ preferBuiltins: true }), commonjs()],
  external: [
    '@aws-sdk/client-dynamodb',
    '@aws-sdk/client-s3',
    '@aws-sdk/lib-storage',
    '@aws-sdk/client-sns',
    '@opentelemetry/api-logs',
    '@opentelemetry/sdk-logs',
    '@opentelemetry/exporter-logs-otlp-http',
    '@opentelemetry/winston-transport',
    '@opentelemetry/resources',
  ],
  onwarn(warning, warn) {
    if (warning.code === 'THIS_IS_UNDEFINED') return;
    warn(warning);
  },
};
