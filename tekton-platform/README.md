# Tekton CI/CD Platform Infrastructure

This directory contains the Tekton CI/CD pipeline configuration designed to automate concurrency management, dynamic change detection, and building/deploying of components using Cloud Native Buildpacks in a single, unified pipeline.

## Architecture & Directory Structure

*   **`base/`**: Holds RBAC permissions, service accounts, sealed secrets (GitHub authentication, GitHub webhook, and GHCR registry credentials), and triggers webhook service manifests.
*   **`pipelines/`**: Defines the CI/CD pipelines:
    *   `orchestrator-pipeline.yaml`: Entrypoint orchestrator pipeline that runs matrix dispatching for all changed component modules in parallel.
    *   `component-pipeline.yaml`: Builder pipeline that runs for each changed component to clone the repository, configure build variables, build using Cloud Native Buildpacks, and deploy the application.
*   **`tasks/`**: Declares individual Tekton tasks containing their inline script logic:
    *   `configure-component.yaml`: Dynamically configures building variables (builder image, target image name, environment variables, default process type, etc.) for a specific component and ensures a `project.toml` configuration is present.
    *   `dispatch-pipelinerun.yaml`: Dynamically triggers a child `component-pipeline` PipelineRun with dedicated workspace/cache PVC configurations, managing stagger delays and concurrency checks.
    *   `patch-deployment.yaml`: Patches the target Kubernetes deployment container with the newly built image tag, creating the deployment if it does not exist, and monitors the rollout to completion.
*   **`templates/`**: Contains language/framework-specific default configuration templates (e.g., `default.toml` files for Node.js, Go, Python, Java, etc.) that can be referenced for component builds.
*   **`triggers/`**: Configures EventListeners (`event-listener.yaml`), TriggerBindings (`github-binding.yaml`), and TriggerTemplates (`trigger-template.yaml`) to trigger builds automatically via Git webhooks.
*   **`scripts/`**: Contains helper utility scripts for workspace management:
    *   `stop-all-running-pipelinerun.sh`: Helper script to cancel/stop all running pipeline runs in the namespace.


---

#### Pipeline Execution Flow

The platform's execution is divided into two separate stages: the main **Orchestrator Pipeline** and the subsequent **Component Pipelines** triggered for each changed component.

### 1. Orchestrator Pipeline Flow
This stage is triggered on any Git `push` event. It clones the repository, detects which components changed, and triggers a downstream build for each changed module.

```mermaid
flowchart TD
    %% Input / Events
    GitHub[GitHub Push Event] -->|HTTP POST JSON Payload| Webhook[Cloudflare Tunnel / ExternalName SVC]
    Webhook -->|JSON Payload| EL[EventListener: gh-event-listener]
    
    %% Webhook Triggers Processing
    EL -->|1. Overlays: changed_modules via CEL interceptor| EL
    EL -->|2. Maps to parameters| Bind1[TriggerBinding: github-merge-binding]
    Bind1 -->|3. Resolves to Template| Temp1[TriggerTemplate: trigger-template]
    Temp1 -->|4. Spawns with changed-modules param| PR1[PipelineRun: orchestrator-pipelinerun]

    %% Orchestrator Pipeline
    subgraph Orchestrator Pipeline [Orchestrator Pipeline Flow]
        PR1 -->|Starts| Pipe1[Pipeline: orchestrator-pipeline]
        Pipe1 -->|Matrix over changed-modules| Task_Dispatch[Task: dispatch-pipelinerun]
        
        %% Concurrency / Matrix Dispatching
        subgraph Matrix Dispatch Loop [Matrix Dispatch per Changed Component]
            Task_Dispatch -->|Step 1: Stagger delay & HTTP POST| DispReq[dispatch-request Step]
            DispReq -->|Triggers component event| EL_Child[EventListener: gh-event-listener]
            DispReq -->|Writes eventID to shared volume| FindChild[find-child-pipelinerun Step]
            FindChild -->|Finds child PipelineRun name| WaitLimit[wait-concurrency-limit Step]
            WaitLimit -->|Checks active component runs against max-concurrency| StartChild[start-pipelinerun Step]
            StartChild -->|Patches status = null| TriggerPR([Trigger Component PipelineRun])
            StartChild -->|Starts child run| MonitorChild[monitor-pipelinerun Step]
            MonitorChild -->|Polls status until finished| MonitorEnd([End component build])
        end
    end

    %% Flow Styling
    classDef pipeline fill:#1A365D,stroke:#3182CE,stroke-width:2px,color:#fff;
    classDef task fill:#2D3748,stroke:#4A5568,stroke-width:1px,color:#fff;
    classDef trigger fill:#2C5282,stroke:#2B6CB0,stroke-width:1.5px,color:#fff;
    classDef input fill:#22543D,stroke:#2F855A,stroke-width:2px,color:#fff;

    class PR1,Pipe1 pipeline;
    class Task_Dispatch task;
    class EL,Bind1,Temp1 trigger;
    class GitHub,Webhook input;
```

### 2. Component Pipeline Flow
This stage runs for each individual changed component. It configures component-specific build variables, packages the app with Paketo buildpacks, and deploys it to the cluster (updating images and validating rollouts matching the `deployment-timeout` configuration).

```mermaid
flowchart TD
    %% Input Event from dispatch-pipelinerun
    DispReq[Orchestrator dispatch-request Step] -->|HTTP POST| EL_Child[EventListener: gh-event-listener]
    
    %% Webhook Triggers Processing
    EL_Child -->|Intercepts component-dispatch event| Bind2[TriggerBinding: component-dispatch-binding]
    Bind2 -->|Parameters: component, timeout, deployment-timeout| Temp2[TriggerTemplate: component-dispatch-template]
    Temp2 -->|Spawns in PENDING status| PR2[PipelineRun: component-pipeline-run]

    %% Component Pipeline (Child Run)
    subgraph Component Pipeline [Component Pipeline Flow]
        PR2 -->|Starts| Pipe2[Pipeline: component-pipeline]
        Pipe2 -->|Step 1| Task_Clone2[Task: git-clone]
        Task_Clone2 -->|Step 2| Task_Config[Task: configure-component]
        
        subgraph Configure Steps [configure-component Task Steps]
            Task_Config --> Config_Cache[create-cache-dir]
            Config_Cache --> Config_Metadata[prepare-metadata]
            Config_Metadata --> Config_Builder[select-builder]
            Config_Builder --> Config_Toml[ensure-project-toml]
            Config_Toml --> Config_Env[parse-env-vars]
            Config_Env --> Config_Proc[output-process-type]
        end
        
        Task_Config -->|Configures environment/builder| Task_BP[Task: buildpacks]
        Task_BP -->|Builds application image using Paketo| Task_Deploy[Task: patch-deployment]
        
        subgraph Deployment Rollout [patch-deployment Task Steps]
            Task_Deploy --> Deploy_Create[create-deployment step]
            Deploy_Create -->|Checks & Creates Deployment if missing| Deploy_Patch[patch-deployment step]
            Deploy_Patch -->|kubectl set image & monitors rollout with deployment-timeout| DeployEnd([Completed Rollout])
        end
    end

    %% Flow Styling
    classDef pipeline fill:#1A365D,stroke:#3182CE,stroke-width:2px,color:#fff;
    classDef task fill:#2D3748,stroke:#4A5568,stroke-width:1px,color:#fff;
    classDef trigger fill:#2C5282,stroke:#2B6CB0,stroke-width:1.5px,color:#fff;
    classDef input fill:#22543D,stroke:#2F855A,stroke-width:2px,color:#fff;

    class PR2,Pipe2 pipeline;
    class Task_Clone2,Task_Config,Task_BP,Task_Deploy task;
    class EL_Child,Bind2,Temp2 trigger;
    class DispReq input;
```

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
   * **Which events**: Select **Just the push event** (the EventListener is configured to trigger on any Git `push` event, rather than pull requests).
   * Click **Add webhook** to register it.

---

## Installation & Deployment

Deploy all platform resources (RBAC, Secrets, Tasks, Pipelines, and Triggers) in a single step using Kustomize:

```bash
kubectl apply -k tekton-platform/
```


## Adding/Modifying Component Builds

Build configurations are maintained directly inside the component directories:
1.  **Component Detection**: Any subdirectory (excluding platform/infrastructure folders like `tekton-platform`, `kubernetes`, `tests`, etc.) is automatically registered as a buildpack-ready component.
2.  **Build Customization**: To customize builder images, environment variables, or buildpacks for a component, define a `project.toml` file in its component directory containing `[[build.env]]` and `[[build.buildpacks]]` blocks. If no `project.toml` is present, a default one will be automatically generated at build time using the detected technology stack.


