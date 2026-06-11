RUN_NAME="orchestrator-pipelinerun-pr-mock-$(date +%s)"
echo "Creating PipelineRun: ${RUN_NAME}."

# For push events, the revision is typically the branch name or commit SHA. For pull request events, the revision is often in the format refs/pull/<PR_NUMBER>/head.

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
EOF
