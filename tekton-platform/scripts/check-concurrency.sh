#!/bin/sh
set -e

CURRENT_RUN="${PIPELINERUN_NAME}"
if [ -z "${CURRENT_RUN}" ]; then
  echo "No PipelineRun name provided. Skipping concurrency check."
  exit 0
fi

echo "Checking concurrency queue status for PipelineRun: ${CURRENT_RUN}"

while true; do
  # Get all running orchestrator PipelineRuns in the namespace, sorted by creation timestamp
  RUNNING_RUNS=$(kubectl get pipelinerun -n saritasa-test -o jsonpath='{range .items[?(@.status.conditions[0].status=="Unknown")]}{.metadata.name}{" "}{.metadata.creationTimestamp}{"\n"}{end}' | grep "^orchestrator-pipelinerun-" | sort -k2)

  if [ -z "${RUNNING_RUNS}" ]; then
    echo "No running PipelineRuns found. Proceeding."
    break
  fi

  # Get the oldest running PipelineRun name
  OLDEST_RUN=$(echo "${RUNNING_RUNS}" | head -n1 | awk '{print $1}')

  if [ "${OLDEST_RUN}" = "${CURRENT_RUN}" ]; then
    echo "Current PipelineRun is the oldest running instance. Proceeding."
    break
  fi

  echo "Current run is queued. Oldest running run is ${OLDEST_RUN}. Waiting for 10 seconds..."
  sleep 10
done
