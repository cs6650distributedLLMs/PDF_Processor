# OpenTelemetry Collectors

- `gateway`: the OpenTelemetry collector used to aggregate the telemetry from all services in this experiment. As the
  name implies, it serves as the gateway to ingest, process, and export telemetry to the target backend.
- `sidecar`: an intermediary OpenTelemetry collector that runs alongside the ECS Fargate app containers. App containers
  offload the telemetry exporting to the Otel sidecar. The sidecar exports telemetry to the gateway collector.

