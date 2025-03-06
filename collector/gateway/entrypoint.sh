#!/usr/bin/env bash

if [ "$OTEL_COLLECTOR_ENV" == "localstack" ]; then
  CONFIG_PATH="/collector/config-localstack.yaml"
else
  CONFIG_PATH="/collector/config.yaml"
fi

exec ${OTEL_COLLECTOR_BIN_PATH} --config ${CONFIG_PATH}
