# Tekton CI/CD Platform Infrastructure

This directory contains the Tekton CI/CD pipeline configuration designed to automate concurrency management, dynamic change detection, and building/deploying of components using Cloud Native Buildpacks in a single, unified pipeline.

## Architecture & Directory Structure

*   **`base/`**: Holds RBAC permissions, service accounts, and webhook secret manifests.
*   **`pipelines/`**: Defines the central CI/CD pipeline:
    *   `orchestrator-pipeline.yaml`: Unified pipeline that runs concurrency check, clones repository, runs change-detection, executes buildpacks build phases, and patches Kubernetes deployments.
*   **`tasks/`**: Declares individual Tekton tasks containing their inline script logic:
    *   `check-concurrency.yaml`: Prevents multiple concurrent runs by queueing runs in order of their creation timestamp.
    *   `detect-changes.yaml`: Scans the cloned workspace to identify which component changed, parses its build configuration, generates/writes the `project.toml` file directly into the workspace, and outputs build metadata.
    *   `patch-deployment.yaml`: Patches the Kubernetes deployment container with the newly built image tag and monitors the rollout to completion.
*   **`triggers/`**: Configures EventListeners, TriggerBindings, and TriggerTemplates to trigger builds automatically via Git webhooks.
*   **`tests/`**: Includes helper shell scripts to test and run mock pipelineruns.

---

## Prerequisites

1.  **Tekton Pipelines and Triggers** installed in your Kubernetes cluster.
2.  **Official `git-clone` task** installed from the Tekton Hub:
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml
    ```
3.  **Official `buildpacks-phases` task** installed from the Tekton Hub:
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/refs/heads/main/task/buildpacks-phases/0.3/buildpacks-phases.yaml
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
2.  **Build Customization**: To change builder images, environment variables, or descriptors for a component, update its `README.md` commands. The configuration is parsed by the `detect-changes.yaml` task and translated into a local `project.toml` file in the workspace containing `[[build.env]]` and `[[build.buildpacks]]` blocks.


