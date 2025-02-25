#!/bin/bash

EPOCH=$(date +%s)
trace_ids=$(awslocal xray get-trace-summaries --start-time $((EPOCH - 1000)) --end-time "$EPOCH" | \
  jq -r '.TraceSummaries[].Id' 2>/dev/null) # Capture jq errors

if [[ -z "$trace_ids" ]]; then
  echo "No traces found within the specified time window."
else
  echo "$trace_ids" | while read -r trace_id; do
    echo "Processing trace ID: $trace_id"
    awslocal xray batch-get-traces --trace-ids "$trace_id" | jq -r '.Traces[].Segments[].Document' | jq -r '.aws'
  done
fi
