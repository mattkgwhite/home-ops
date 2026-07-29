# Platforms

| Platform | Status | Guide | Live configuration |
| --- | --- | --- | --- |
| Kubernetes | Active plus experiments | [Guide](kubernetes/README.md) | [`kubernetes/`](../../kubernetes/) |
| Hetzner | Active; verify inventory | [Guide](hetzner/README.md) | [`ansible/inventory/`](../../ansible/inventory/) |
| Storage | Active SMB; NAS proposed | [Guide](storage/README.md) | [`storage.yaml`](../../kubernetes/argo/manifests/storage.yaml) |
| Cloudflare | Active integration | [Guide](cloudflare/README.md) | [`cloudflared.yaml`](../../kubernetes/argo/manifests/cloudflared.yaml) |
| Networking | Active cluster layer | [Guide](networking/README.md) | [`kube-system.yaml`](../../kubernetes/argo/manifests/kube-system.yaml) |
| Mini-rack | Proposed | [Guide](mini-rack/README.md) | None |

Each guide covers architecture, configuration, deployment, upgrades,
troubleshooting, and links to implementation.
