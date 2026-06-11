#!/bin/sh
set -e

# Setup Docker Config for registry credentials if provided by Tekton
if [ -f "/tekton/creds/.docker/config.json" ]; then
  mkdir -p ~/.docker
  cp /tekton/creds/.docker/config.json ~/.docker/config.json
elif [ -d "/tekton/creds" ]; then
  export DOCKER_CONFIG="/tekton/creds"
fi

BUILDPACK_ARG=""
if [ -n "${BUILDPACK}" ]; then
  BUILDPACK_ARG="--buildpack ${BUILDPACK}"
fi

# Execute pack build daemonless and push directly to registry
pack build "${APP_IMAGE}" \
  --builder "${BUILDER_IMAGE}" \
  --path "${WORKSPACE_PATH}/${SOURCE_SUBPATH}" \
  ${BUILDPACK_ARG} \
  ${ADDITIONAL_ARGS} \
  --publish
