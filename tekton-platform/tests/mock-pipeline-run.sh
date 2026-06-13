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
    podTemplate:
      nodeSelector:
        node: hp
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
        value: "feature/test-ci-cd-2-changes"
      - name: gitrepositoryurl
        value: "https://github.com/khanhcmlab/saritasa-devops-build-samples"
EOF
