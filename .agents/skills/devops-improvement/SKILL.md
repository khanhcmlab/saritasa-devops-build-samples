---
name: devops-improvement
description: Guidelines and best practices for Kubernetes, Tekton, and DevOps configurations based on PR #1 feedback.
---

# DevOps & Tekton Guidelines

This guide details the conventions, best practices, and code review standards for managing Kubernetes manifests, Tekton Pipelines, and secrets within the codebase. These guidelines are compiled from code review feedback in PR #1.

## 1. Kubernetes Manifests & Styling

### Formatting & Syntax
* **List Formatting**: Prefer multi-line lists for array values (such as Role/ClusterRole `verbs` and `resources`) and keep them sorted in alphabetical (ascending) order.
  ```yaml
  verbs:
    - create
    - delete
    - get
    - list
    - watch
  ```
* **No Hardcoded Namespaces**: Do not hardcode namespaces in resource manifests (e.g. `namespace: test`). Use **Kustomize** to overlay and inject namespaces dynamically at deploy time.
* **Standard Metadata Labels**: All provisioned resources must include standard, typical Kubernetes labels to clearly associate dependencies with the project:
  ```yaml
  metadata:
    labels:
      app.kubernetes.io/name: <app-name>
      app.kubernetes.io/instance: <environment-instance>
      app.kubernetes.io/version: "1.0.0"
      app.kubernetes.io/component: <backend|frontend|infrastructure>
      app.kubernetes.io/part-of: devops-build-samples
      app.kubernetes.io/managed-by: <kustomize|argocd|helm>
  ```
* **Documenting External Resources**: If you do not provision a resource as part of the solution but reference it as a dependency, explain via an annotation or inline comment where that resource is defined (e.g., in a central cluster config) to aid maintenance.

---

## 2. Secrets & Security

* **Secret Maintenance Metadata**: Every secret resource, from a maintenance perspective, must include comments/annotations explaining:
  1. Why it is needed
  2. Expiration date
  3. How to renew it
  4. Where to renew it (reference URL)
* **RBAC & Principle of Least Privilege**: Reduce RBAC permissions for the ServiceAccount used by the pipeline to the bare minimum necessary. Avoid granting cluster-wide roles or extra role bindings if the pipeline can function without them.

---

## 3. Tekton Pipelines & Tasks

* **Param Descriptions**: All parameters must include a clear `description` explaining the purpose of the argument.
* **No Default Values in Declarations**: Do not specify `default` values directly in Pipeline or Task declarations. If a value is missing, the admission controller should fail fast with a proper validation error rather than silently ignoring the missing input.
* **Single Source of Truth**: All parameter values should originate from a single source of truth (such as `TriggerBindings`) associated by a `TriggerTemplate`.
* **Kebab-Case Naming**: Maintain naming consistency. Use kebab-case (`xxx-yyy`) everywhere for parameter, task, and workspace names. Avoid camelCase (`xxxYyy`) or uppercase (`XXX_YYY`).
* **Task Purpose**: Each Task file must contain a `description` section or inline comments explaining the high-level purpose of the task.

---

## 4. Pipeline Concurrency & Architecture

* **Orchestrator Concurrency Control**: Avoid checking concurrency inside each component task using blocking wait steps (which spawn pods and consume cluster resources unnecessarily). Instead, control concurrency from the orchestrator level by dispatching pipeline runs sequentially or in a staggered fashion (e.g., using a matrix with a max concurrency configuration).
* **API-Driven Dispatch**: Prefer using a `curl -X POST` call against the `EventListener` service to dispatch component pipelineruns rather than creating PipelineRun resources directly with `kubectl` (which requires higher RBAC permissions for the dispatcher).
* **Change Detection**: Prefer Tekton overlays (such as CEL interceptors) to obtain list of changed files/modules dynamically instead of executing custom Git diff steps.
* **Cache Efficiency**: Validate that the buildpack layers cache workspace is correctly mounted and utilized, ensuring builds do not take several minutes to restore layer cache.
