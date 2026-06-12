#!/usr/bin/env bash
set -e

NAMESPACE="saritasa-test"
REPOSITORY="https://github.com/khanhcmlab/saritasa-devops-build-samples"
REVISION="main"

echo "Spawning 3 concurrent orchestrator PipelineRuns..."

for i in {1..3}; do
  RUN_NAME="orchestrator-pipelinerun-mock-${i}-$(date +%s)"
  echo "Creating PipelineRun: ${RUN_NAME}"
  
  cat <<EOF | kubectl apply -f -
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: ${RUN_NAME}
  namespace: ${NAMESPACE}
spec:
  serviceAccountName: pipeline-service-account
  pipelineRef:
    name: orchestrator-pipeline
  workspaces:
    - name: source-workspace
      volumeClaimTemplate:
        spec:
          storageClassName: nfs-rwx
          accessModes:
            - ReadWriteMany
          resources:
            requests:
              storage: 1Gi
  params:
    - name: gitrevision
      value: "${REVISION}"
    - name: gitrepositoryurl
      value: "${REPOSITORY}"
EOF
  # Introduce a small delay to guarantee distinct creation timestamps
  sleep 2
done