# Tekton CI/CD Platform Infrastructure

This directory contains the Tekton CI/CD pipeline configuration designed to automate concurrency management, dynamic change detection, and building/deploying of components using Cloud Native Buildpacks in a single, unified pipeline.

## Architecture & Directory Structure

*   **`base/`**: Holds RBAC permissions, service accounts, sealed secrets (GitHub authentication, GitHub webhook, and GHCR registry credentials), and triggers webhook service manifests.
*   **`pipelines/`**: Defines the CI/CD pipelines:
    *   `orchestrator-pipeline.yaml`: Entrypoint orchestrator pipeline that runs concurrency checks, clones the repository, detects component changes, and dynamically dispatches individual component builds in parallel.
    *   `component-pipeline.yaml`: Builder pipeline that runs for each changed component to configure build variables, run Cloud Native Buildpacks building phases, and optionally deploy the application.
*   **`tasks/`**: Declares individual Tekton tasks containing their inline script logic:
    *   `check-concurrency.yaml`: Prevents multiple concurrent runs by queueing pipeline runs in order of their creation timestamp.
    *   `detect-changes.yaml`: Scans the cloned workspace using `git diff` to identify which components changed and outputs a JSON list of those components.
    *   `configure-component.yaml`: Dynamically configures building variables (builder image, target image name, environment variables, default process type, etc.) for a specific component and ensures a `project.toml` configuration is present.
    *   `dispatch-pipelinerun.yaml`: Dynamically triggers a child `component-pipeline` PipelineRun with dedicated workspace/cache PVC configurations for a specific component.
    *   `patch-deployment.yaml`: Patches the target Kubernetes deployment container with the newly built image tag and monitors the rollout to completion.
*   **`templates/`**: Contains language/framework-specific default configuration templates (e.g., `default.toml` files for Node.js, Go, Python, Java, etc.) that can be referenced for component builds.
*   **`triggers/`**: Configures EventListeners (`event-listener.yaml`), TriggerBindings (`github-binding.yaml`), and TriggerTemplates (`trigger-template.yaml`) to trigger builds automatically via Git webhooks.
*   **`scripts/`**: Contains helper utility scripts for workspace management:
    *   `stop-all-running-pipelinerun.sh`: Helper script to cancel/stop all running pipeline runs in the namespace.
*   **`tests/`**: Includes helper shell scripts to test and run mock pipelineruns:
    *   `mock-pipeline-run.sh`: Triggers a mock orchestrator pipeline run manually.

---

## Prerequisites

1.  **Tekton Pipelines and Triggers** installed in your Kubernetes cluster.
    *   **Install Tekton Pipelines**:
        ```bash
        kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
        ```
        Verify that all components are running:
        ```bash
        kubectl get pods --namespace tekton-pipelines --watch
        ```
    *   **Install Tekton Triggers and Interceptors**:
        ```bash
        kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
        kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
        ```
        For more details, refer to the [Tekton Getting Started Guide](https://tekton.dev/docs/getting-started/).
2.  **Official `git-clone` task** installed from the Tekton Hub:
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml
    ```
3.  **Official `buildpacks-phases` task** installed from the Tekton Hub:
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/refs/heads/main/task/buildpacks-phases/0.3/buildpacks-phases.yaml
    ```
4.  **Sealed Secrets Controller** installed and configured in your Kubernetes cluster:
    *   The platform infrastructure uses `SealedSecrets` (found in the `base/` directory) to safely store and decrypt GitHub credentials and GHCR registry secrets.
    *   **Install Sealed Secrets**:
        ```bash
        kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.21.0/controller.yaml
        ```
        For more details and customization options, see the [Sealed Secrets Docs](https://github.com/bitnami-labs/sealed-secrets).
5.  **Configure Tekton Feature Flags**: By default, Tekton's Affinity Assistant restricts task runs to using at most one PVC-based workspace under the default `coschedule: workspaces` mode. Since the component pipeline binds multiple PVCs (for source and cache), you must update the `coschedule` flag to `pipelineruns` in the `feature-flags` ConfigMap under the `tekton-pipelines` namespace:
    ```bash
    kubectl patch cm feature-flags -n tekton-pipelines --type=merge -p '{"data":{"coschedule":"pipelineruns"}}'
    ```

---

## GitHub Webhook Configuration

To trigger pipeline builds automatically when code is pushed to GitHub, you need to configure a GitHub Webhook:

1. **Expose the EventListener (via Cloudflare Tunnel)**:
   * The platform exposes the EventListener via `tekton-platform/base/triggers-webhook-service.yaml`, which forwards requests from the `default` namespace to the actual `el-gh-event-listener` running in the `saritasa-test` namespace using an `ExternalName` service:
     ```yaml
     apiVersion: v1
     kind: Service
     metadata:
       name: gh-listener-webhook
       namespace: default
     spec:
       type: ExternalName
       externalName: el-gh-event-listener.saritasa-test.svc.cluster.local
     ```
   * Expose this forwarded `gh-listener-webhook` service (running on port `8080` in the `default` namespace) to the internet by routing it through your **Cloudflare Tunnel** (`cloudflared`) pointing to `http://gh-listener-webhook.default.svc.cluster.local:8080`.
2. **Configure the Webhook on GitHub**:
   * Go to your repository on GitHub -> **Settings** -> **Webhooks** -> **Add webhook**.
   * **Payload URL**: Enter your exposed public URL (e.g., `https://<your-cloudflare-tunnel-domain>`).
   * **Content type**: Select `application/json`.
   * **Secret**: Enter the webhook secret token matching the value configured in your Kubernetes `github-webhook-secret` (defined under the `token` key).
   * **Which events**: Select **Just the push event** (the EventListener is configured to intercept `push` events).
   * Click **Add webhook** to register it.

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

You can trigger a mock pipeline run manually with:

```bash
bash tekton-platform/tests/mock-pipeline-run.sh
```

To test concurrency queuing and parallel processing, you can run the mock script multiple times in quick succession.

---

## Adding/Modifying Component Builds

Build configurations are maintained directly inside the component directories:
1.  **Component Detection**: Any subdirectory (excluding platform/infrastructure folders like `tekton-platform`, `kubernetes`, `tests`, etc.) is automatically registered as a buildpack-ready component.
2.  **Build Customization**: To customize builder images, environment variables, or buildpacks for a component, define a `project.toml` file in its component directory containing `[[build.env]]` and `[[build.buildpacks]]` blocks. If no `project.toml` is present, a default one will be automatically generated at build time using the detected technology stack.


