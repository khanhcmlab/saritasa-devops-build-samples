RUN_NAME="orchestrator-pipelinerun-mock-$(date +%s)"
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
            storageClassName: local-path
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 1Gi
    params:
      - name: git-revision
        value: "feature/test-ci-cd-2-changes"
      - name: git-repository-url
        value: "https://github.com/khanhcmlab/saritasa-devops-build-samples" 
      - name: action
        value: "deploy"
      - name: registry-path
        value: "ghcr.io/dewwripper"
      - name: max-concurrency
        value: "2"
      - name: namespace
        value: "saritasa-test"
      - name: container-name
        value: "app"
      - name: clone-depth
        value: "2"
      - name: delete-existing
        value: "true"
      - name: pipeline-timeout
        value: "5m"
      - name: deployment-timeout
        value: "60s"
      - name: workspace-size
        value: "1Gi"
      - name: find-child-timeout
        value: "30"
      - name: changed-modules
        value: '["python/pipenv", "dotnet-core/fde-app", "nodejs/react-yarn", "java/dist-zip", "go/mod", "python/poetry", "ruby/puma"]'
EOF
