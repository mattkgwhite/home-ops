# Kubernetes Configuration

- `argo/manifests/` contains the active Argo CD application set.
- `argo/not-deployed/` contains candidates that are not part of current state.
- `flux/` is an experimental Flux path.
- `talos/` contains experimental Talos patches.
- `archived/` preserves retired configuration.
- `vps/` contains code-adjacent deployment and troubleshooting notes.

See the [Kubernetes platform guide](../docs/platforms/kubernetes/README.md).
Changes here may reconcile to live infrastructure.
