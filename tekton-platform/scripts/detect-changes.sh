#!/bin/sh
set -e

# Dynamically discover all components containing a README.md file with 'pack build' inside
MODULES=""
for readme in $(find . -name "README.md" | grep -v "^./README.md$"); do
  if grep -q "pack build" "${readme}"; then
    dir=$(dirname "${readme}" | sed 's|^\./||')
    MODULES="${MODULES} ${dir}"
  fi
done

CHANGED_COMPONENTS=""
for dir in ${MODULES}; do
  if git diff-tree --no-commit-id --name-only -r HEAD | grep -q "^${dir}/"; then
    CHANGED_COMPONENTS="${CHANGED_COMPONENTS} ${dir}"
  fi
done

if [ -z "${CHANGED_COMPONENTS}" ]; then
  echo "[NO-OP] No buildpack-ready components changed."
  echo -n "" > "${RESULT_PATH}"
  exit 0
fi

CHANGED_COMPONENTS=$(echo "${CHANGED_COMPONENTS}" | xargs)
echo -n "${CHANGED_COMPONENTS}" > "${RESULT_PATH}"

for component in ${CHANGED_COMPONENTS}; do
  echo "Dispatched PipelineRun for component: ${component}"
done
