#!/usr/bin/env bash

if [ "$APPLICATION_ENVIRONMENT" == "localstack" ]; then
  CONFIG_PATH="/collector/config.yaml"
else
  CONFIG_PATH="/collector/config-with-ecs-metrics.yaml"
fi

exec ${OTEL_COLLECTOR_BIN_PATH} --config ${CONFIG_PATH}
