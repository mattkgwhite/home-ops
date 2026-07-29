# Architecture

Home-ops uses Git as the durable record for infrastructure intent,
documentation, and automation. Kubernetes workloads are declared in Git and
reconciled through GitOps. Ansible handles host-level work outside the cluster.

```text
Operators -> Git -> Argo CD -> K3s -> platform services
                 \-> Ansible -> Linux / Hetzner hosts

Cloudflare + Tailscale -> external/private access
1Password -> External Secrets -> Kubernetes secrets
Hetzner Storage Box -> SMB CSI -> persistent volumes
```

The diagram is conceptual, not a complete network or trust-boundary model.

## Principles

- Git is the source for desired state; runtime drift is reconciled back.
- Secrets are referenced from 1Password and are not committed decrypted.
- Documentation accompanies design and operational changes.
- Experimental and archived configurations stay labelled.
- Recovery is tested, not inferred from the presence of backups.

See the [system context](system-context.md), [platform index](../platforms/README.md),
[ADRs](../../adr/README.md), and [current design](../../CURRENT-DESIGN.md).
