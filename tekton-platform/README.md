# Tekton CI/CD Platform Infrastructure

This directory contains the Tekton CI/CD pipeline configuration designed to automate concurrency management, dynamic change detection, and parallel building/deploying of components using Cloud Native Buildpacks (via the `pack` CLI).

## Architecture & Directory Structure

*   **`base/`**: Holds RBAC permissions, service accounts, and webhook secret manifests.
*   **`pipelines/`**: Defines the central orchestrator pipeline (`orchestrator-pipeline.yaml`).
*   **`tasks/`**: Declares individual Tekton tasks. The task scripts have been refactored into external shell scripts for clean development and testing.
*   **`scripts/`**: Contains the shell scripts executed by the tasks (called dynamically from the pipeline's workspace):
    *   `check-concurrency.sh`: Prevents multiple concurrent runs by queueing runs in order of their creation timestamp.
    *   `detect-changes.sh`: Scans the repository to identify components (subdirectories containing a `README.md` with a `pack build` instruction) and detects which components changed in the git revision.
    *   `dispatch-pipeline-runs.sh`: Reads configuration parameters for changed components and dispatches individual `PipelineRun` builders.
    *   `buildpack-build.sh`: Runs the actual `pack build` process with custom builder images, buildpacks, env parameters, and descriptors.
    *   `patch-deployment.sh`: Patches the Kubernetes deployment container and monitors the rollout to completion.
*   **`triggers/`**: Configures EventListeners, TriggerBindings, and TriggerTemplates to trigger builds automatically via Git webhooks.
*   **`tests/`**: Includes helper shell scripts to test and run mock pipelineruns.

---

## Prerequisites

1.  **Tekton Pipelines and Triggers** installed in your Kubernetes cluster.
2.  **Official `git-clone` task** installed from the Tekton Hub:
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml
    ```

---

## Installation & Deployment

Apply the manifests in the following order:

```bash
# 1. Setup RBAC and Secrets
kubectl apply -f tekton-platform/base/

# 2. Register Tasks
kubectl apply -f tekton-platform/tasks/

# 3. Register Pipelines
kubectl apply -f tekton-platform/pipelines/

# 4. Setup Webhook Triggers
kubectl apply -f tekton-platform/triggers/
```

---

## Running and Testing Mock Pipelines

You can trigger a mock pull request pipeline run manually with:

```bash
bash tekton-platform/tests/mock-pipeline-run.sh
```

To test concurrency queuing and parallel processing, run:

```bash
bash tekton-platform/tests/mock-parallel-pipeline-run.sh
```

---

## Adding/Modifying Component Builds

Build configurations are maintained directly inside the component directories:
1.  **Component Detection**: Any new subdirectory with a `README.md` containing `pack build` is automatically registered as a component at runtime.
2.  **Build Customization**: To change builder images, environment variables, or descriptors for a component, update its `README.md` commands. The configuration is hardcoded in the `dispatch-pipeline-runs.sh` script to parse and translate these parameters into Tekton resources.
