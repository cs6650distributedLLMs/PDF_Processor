#!/usr/bin/env bash

if [ "$OTEL_COLLECTOR_ENV" == "localstack" ]; then
  CONFIG_PATH="/collector/config.yaml"
else
  CONFIG_PATH="/collector/config-with-ecs-metrics.yaml"
fi

exec ${OTEL_COLLECTOR_BIN_PATH} --config ${CONFIG_PATH}
