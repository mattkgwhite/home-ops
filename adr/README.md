# Architecture Decision Records

ADRs are immutable decision history. Create the next numbered file from
[`0000-template.md`](0000-template.md). When a decision changes, add a new ADR
and mark the old one superseded rather than rewriting history.

| ADR | Status | Decision |
| --- | --- | --- |
| [0001](0001-use-an-external-nas.md) | Proposed | External NAS |
| [0002](0002-use-a-16u-rack.md) | Proposed | 16U rack |
| [0003](0003-standardise-on-unifi-networking.md) | Proposed | UniFi networking |
| [0004](0004-use-k3s.md) | Accepted | K3s |
| [0005](0005-use-argo-cd-for-gitops.md) | Accepted | Argo CD |
| [0006](0006-adopt-a-layered-backup-strategy.md) | Proposed | Backup strategy |

Accepted means the repository contains clear implementation evidence. Proposed
records require validation or an explicit approval before implementation.
