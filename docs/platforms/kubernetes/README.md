# Kubernetes Platform

## Architecture overview

The documented deployment is a single-node K3s cluster on a Hetzner VPS.
Argo CD is the primary GitOps reconciler. Cilium supplies networking, CoreDNS
service discovery, and Envoy Gateway implements Gateway API. Flux and Talos are
experiments and are not asserted as the production control path.

## Configuration overview

Argo CD Applications are in
[`kubernetes/argo/manifests/`](../../../kubernetes/argo/manifests/). Candidates
are separated in
[`kubernetes/argo/not-deployed/`](../../../kubernetes/argo/not-deployed/).

## Deployment notes

Read [Argo CD deployment notes](argo-cd-deployment.md) and the
[VPS notes](../../../kubernetes/vps/argo.md). Render Helm or Kustomize output
before applying. Never copy bootstrap secrets into Git.

## Upgrade procedure

1. Read release notes and API compatibility guidance.
2. Review CRD compatibility before changing a target revision.
3. Render and inspect the proposed output.
4. Upgrade one control-plane component at a time and observe reconciliation.
5. Record results and update the current design if needed.

TODO: Add tested commands and rollback criteria for the running cluster.

## Troubleshooting

Check Argo application health, events, controller logs, DNS, and gateway status.
Use the [Envoy runbook](../../../kubernetes/vps/envoy-gateway-setup.md).

## Live configuration

- [Argo CD](../../../kubernetes/argo/manifests/)
- [Flux](../../../kubernetes/flux/)
- [Talos patches](../../../kubernetes/talos/patches/)
- [Bootstrap scripts](../../../scripts/)
