#!/usr/bin/env bash

exec ${OTEL_COLLECTOR_BIN_PATH} --config ${OTEL_COLLECTOR_CONFIG_PATH}
