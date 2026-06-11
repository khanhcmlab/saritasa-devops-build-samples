RUN_NAME="orchestrator-pipelinerun-pr-mock-${i}-$(date +%s)"
echo "Creating PipelineRun: ${RUN_NAME}"
cat <<EOF | kubectl apply -f -
  apiVersion: tekton.dev/v1beta1
  kind: PipelineRun
  metadata:
    name:  ${RUN_NAME}
    namespace: saritasa-test
  spec:
    serviceAccountName: pipeline-service-account
    pipelineRef:
      name: orchestrator-pipeline
    params:
      - name: gitrevision
        value: "refs/pull/2/head"
      - name: gitrepositoryurl
        value: "https://github.com/khanhcmlab/saritasa-devops-build-samples"
    workspaces:
      - name: shared-workspace
        emptyDir: {}
EOF
