#!/bin/sh
set -e

if [ -z "${CHANGED_COMPONENTS}" ]; then
  echo "No components changed. Nothing to build or deploy."
  exit 0
fi

for component in ${CHANGED_COMPONENTS}; do
  # Clean up the name for Kubernetes resource naming (replace slash with hyphen)
  clean_name=$(echo "${component}" | tr '/' '-')

  # Initialize default values
  builder="paketobuildpacks/builder-jammy-base:latest"
  buildpack=""
  additional_args=""
  source_subpath="${component}"

  case "${component}" in
    "ca-certificates/ca-certificates-sample")
      buildpack="paketo-buildpacks/go"
      ;;
    "dotnet-core/aspnet")
      buildpack="paketo-buildpacks/dotnet-core"
      ;;
    "dotnet-core/fdd-app")
      buildpack="paketo-buildpacks/dotnet-core"
      ;;
    "dotnet-core/fde-app")
      buildpack="paketo-buildpacks/dotnet-core"
      ;;
    "dotnet-core/runtime")
      buildpack="paketo-buildpacks/dotnet-core"
      ;;
    "dotnet-core/self-contained-deployment")
      buildpack="paketo-buildpacks/dotnet-core"
      ;;
    "git/git-sample")
      buildpack="paketo-buildpacks/git"
      source_subpath="git/git-sample/app"
      ;;
    "go/mod")
      buildpack="paketo-buildpacks/go"
      ;;
    "go/no-imports")
      buildpack="paketo-buildpacks/go"
      ;;
    "java/akka")
      additional_args="--env BP_JVM_VERSION=11"
      ;;
    "java/application-insights")
      additional_args="--env BP_JVM_VERSION=17"
      ;;
    "java/aspectj")
      additional_args="--env BP_JVM_VERSION=17"
      ;;
    "java/deps")
      additional_args="--env BP_JVM_VERSION=11"
      ;;
    "java/dist-zip")
      additional_args='--env BP_GRADLE_BUILD_ARGUMENTS="--no-daemon -x test bootDistZip" --env BP_GRADLE_BUILT_ARTIFACT="build/distributions/*.zip" --env BP_JVM_VERSION=17'
      ;;
    "java/jar")
      additional_args="--env BP_JVM_VERSION=17"
      ;;
    "java/java-node/gradle-node")
      builder="paketobuildpacks/builder-jammy-base"
      additional_args="--env BP_JVM_VERSION=21 --env BP_JAVA_INSTALL_NODE=true --env BP_NODE_PROJECT_PATH=frontend"
      ;;
    "java/java-node/maven-yarn")
      additional_args="--env BP_JVM_VERSION=17 --env BP_JAVA_INSTALL_NODE=true"
      ;;
    "java/kotlin")
      additional_args="--env BP_JVM_VERSION=17"
      ;;
    "java/leiningen")
      additional_args="--env BP_JVM_VERSION=11"
      ;;
    "java/native-image/quarkus-native-image-maven")
      builder="paketobuildpacks/builder-jammy-tiny"
      additional_args='--env BP_NATIVE_IMAGE=true --env BP_MAVEN_ADDITIONAL_BUILD_ARGUMENTS="-Dquarkus.package.type=native-sources" --env BP_MAVEN_BUILT_ARTIFACT="target/native-sources" --env BP_NATIVE_IMAGE_BUILD_ARGUMENTS_FILE="native-sources/native-image.args" --env BP_NATIVE_IMAGE_BUILT_ARTIFACT="native-sources/*-runner.jar" --env BP_JVM_VERSION=21'
      ;;
    "java/native-image/spring-boot-native-image-gradle")
      builder="paketobuildpacks/builder-jammy-tiny"
      additional_args="--env BP_NATIVE_IMAGE=true"
      ;;
    "java/native-image/spring-boot-native-image-maven")
      builder="paketobuildpacks/builder-jammy-tiny"
      additional_args='--env BP_NATIVE_IMAGE=true --env BP_MAVEN_BUILD_ARGUMENTS="-Dmaven.test.skip=true --no-transfer-progress package -Pnative" --env BP_JVM_VERSION=17'
      ;;
    "java/opentelemetry")
      additional_args="--buildpack paketo-buildpacks/java --buildpack docker.io/paketobuildpacks/opentelemetry --env BP_OPENTELEMETRY_ENABLED=true --env BP_JVM_VERSION=17"
      ;;
    "java/war-spring")
      additional_args="--env BP_JVM_VERSION=17 --env BP_TOMCAT_VERSION=10"
      ;;
    "nodejs/angular-npm")
      buildpack="paketo-buildpacks/nodejs"
      additional_args='--env BP_NODE_RUN_SCRIPTS=build --env NODE_ENV=development'
      ;;
    "nodejs/no-package-manager")
      buildpack="paketo-buildpacks/nodejs"
      ;;
    "nodejs/npm")
      buildpack="paketo-buildpacks/nodejs"
      ;;
    "nodejs/react-yarn")
      buildpack="paketo-buildpacks/nodejs"
      additional_args='--env BP_NODE_RUN_SCRIPTS=build'
      ;;
    "nodejs/vue-npm")
      buildpack="paketo-buildpacks/nodejs"
      additional_args='--env BP_NODE_RUN_SCRIPTS=build --env NODE_ENV=development'
      ;;
    "nodejs/yarn")
      buildpack="paketo-buildpacks/nodejs"
      ;;
    "php/app_with_extensions")
      buildpack="paketo-buildpacks/php"
      builder="paketobuildpacks/builder-jammy-full"
      ;;
    "php/builtin-server")
      buildpack="paketo-buildpacks/php"
      builder="paketobuildpacks/builder-jammy-full"
      ;;
    "php/composer")
      buildpack="paketo-buildpacks/php"
      builder="paketobuildpacks/builder-jammy-full"
      additional_args="--env BP_PHP_WEB_DIR=htdocs"
      ;;
    "php/composer_with_extensions")
      buildpack="paketo-buildpacks/php"
      builder="paketobuildpacks/builder-jammy-full"
      ;;
    "php/httpd")
      buildpack="paketo-buildpacks/php"
      builder="paketobuildpacks/builder-jammy-full"
      ;;
    "php/memcached_session_handler")
      buildpack="paketo-buildpacks/php"
      builder="paketobuildpacks/builder-jammy-full"
      additional_args="--env BP_PHP_WEB_DIR=htdocs --env SERVICE_BINDING_ROOT=/bindings"
      ;;
    "php/nginx")
      buildpack="paketo-buildpacks/php"
      builder="paketobuildpacks/builder-jammy-full"
      ;;
    "php/redis_session_handler")
      buildpack="paketo-buildpacks/php"
      builder="paketobuildpacks/builder-jammy-full"
      additional_args="--env BP_PHP_WEB_DIR=htdocs --env SERVICE_BINDING_ROOT=/bindings"
      ;;
    "python/conda")
      buildpack="paketo-buildpacks/python"
      ;;
    "python/no_package_manager")
      buildpack="paketo-buildpacks/python"
      ;;
    "python/pip")
      buildpack="paketo-buildpacks/python"
      ;;
    "python/pipenv")
      buildpack="paketo-buildpacks/python"
      ;;
    "python/poetry")
      buildpack="paketo-buildpacks/python"
      ;;
    "python/poetry-run")
      buildpack="paketo-buildpacks/python"
      ;;
    "ruby/passenger")
      buildpack="paketo-buildpacks/ruby"
      ;;
    "ruby/puma")
      buildpack="paketo-buildpacks/ruby"
      ;;
    "ruby/rackup")
      buildpack="paketo-buildpacks/ruby"
      ;;
    "ruby/rails_assets")
      buildpack="paketo-buildpacks/ruby"
      ;;
    "ruby/rake")
      buildpack="paketo-buildpacks/ruby"
      ;;
    "ruby/thin")
      buildpack="paketo-buildpacks/ruby"
      ;;
    "ruby/unicorn")
      buildpack="paketo-buildpacks/ruby"
      ;;
    "web-servers/angular-nginx-sample")
      buildpack="paketo-buildpacks/web-servers"
      additional_args="--env BP_NODE_RUN_SCRIPTS=build --env BP_WEB_SERVER=nginx --env BP_WEB_SERVER_ROOT=dist/my-project-name --env BP_WEB_SERVER_ENABLE_PUSH_STATE=true"
      ;;
    "web-servers/httpd-sample")
      buildpack="paketo-buildpacks/httpd"
      builder="paketobuildpacks/builder-jammy-full:latest"
      ;;
    "web-servers/nginx-sample")
      buildpack="paketo-buildpacks/nginx"
      ;;
    "web-servers/react-frontend-sample")
      additional_args="--descriptor httpd.toml"
      ;;
  esac

  # Define the target registry and image name
  app_image="ghcr.io/saritasa-test/${clean_name}:${GITREVISION}"

  echo "Dispatching PipelineRun for ${component} with action ${ACTION}..."

  if [ "${ACTION}" = "deploy" ]; then
    cat <<EOF | kubectl apply -f -
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: deploy-${clean_name}-
  namespace: saritasa-test
spec:
  serviceAccountName: pipeline-service-account
  taskSpec:
    workspaces:
      - name: source
    tasks:
      - name: git-clone
        taskRef:
          name: git-clone
        workspaces:
          - name: output
            workspace: source
        params:
          - name: url
            value: "${GITREPOSITORYURL}"
          - name: revision
            value: "${GITREVISION}"
      - name: build-task
        runAfter:
          - git-clone
        taskRef:
          name: buildpack-build
        workspaces:
          - name: source
            workspace: source
        params:
          - name: APP_IMAGE
            value: "${app_image}"
          - name: BUILDER_IMAGE
            value: "${builder}"
          - name: SOURCE_SUBPATH
            value: "${source_subpath}"
          - name: BUILDPACK
            value: "${buildpack}"
          - name: ADDITIONAL_ARGS
            value: "${additional_args}"
      - name: patch-deployment
        runAfter:
          - build-task
        taskRef:
          name: patch-deployment
        workspaces:
          - name: source
            workspace: source
        params:
          - name: DEPLOYMENT_NAME
            value: "${clean_name}"
          - name: IMAGE_NAME
            value: "ghcr.io/saritasa-test/${clean_name}"
          - name: TAG
            value: "${GITREVISION}"
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
EOF
  else
    cat <<EOF | kubectl apply -f -
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: build-${clean_name}-
  namespace: saritasa-test
spec:
  serviceAccountName: pipeline-service-account
  taskSpec:
    workspaces:
      - name: source
    tasks:
      - name: git-clone
        taskRef:
          name: git-clone
        workspaces:
          - name: output
            workspace: source
        params:
          - name: url
            value: "${GITREPOSITORYURL}"
          - name: revision
            value: "${GITREVISION}"
      - name: build-task
        runAfter:
          - git-clone
        taskRef:
          name: buildpack-build
        workspaces:
          - name: source
            workspace: source
        params:
          - name: APP_IMAGE
            value: "${app_image}"
          - name: BUILDER_IMAGE
            value: "${builder}"
          - name: SOURCE_SUBPATH
            value: "${source_subpath}"
          - name: BUILDPACK
            value: "${buildpack}"
          - name: ADDITIONAL_ARGS
            value: "${additional_args}"
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
EOF
  fi
done
