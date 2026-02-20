# Automation

## Crossplane

Crossplane is an open-source control plane framework that extends Kubernetes to manage and provision cloud infrastructure and services through declarative APIs. It lets platform teams build custom control planes and orchestrate resources across providers using familiar Kubernetes tooling.

### Overview

Crossplane transforms a standard Kubernetes cluster into a **universal control plane** by adding custom resource definitions (CRDs) representing external infrastructure (e.g., databases, compute, storage) and controllers that continuously reconcile desired state. This allows you to manage cloud resources alongside Kubernetes workloads using a single, Kubernetes-native API.

Key capabilities include:

- **Kubernetes-style declarative management** of external resources.
- **Multi-cloud support** through providers for major cloud platforms.
- **Composable infrastructure abstractions** for reusable platform APIs.

Crossplane is a CNCF-hosted project, vendor-neutral, and designed to be extensible for custom platform engineering workflows.