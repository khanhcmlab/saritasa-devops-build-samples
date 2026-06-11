#!/bin/sh
set -e

echo "Patching deployment '${DEPLOYMENT_NAME}' in namespace '${NAMESPACE}'..."
echo "Setting image for container '${CONTAINER_NAME}' to '${IMAGE_NAME}:${TAG}'..."

# Update the deployment's container image
kubectl set image deployment/${DEPLOYMENT_NAME} \
  ${CONTAINER_NAME}=${IMAGE_NAME}:${TAG} \
  -n ${NAMESPACE}

# Monitor and verify the rollout status
echo "Waiting for rollout to complete..."
kubectl rollout status deployment/${DEPLOYMENT_NAME} -n ${NAMESPACE}
