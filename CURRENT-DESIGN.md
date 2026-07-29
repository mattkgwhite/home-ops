# Current Design

- **Current version:** 2026.08 handbook baseline
- **Current status:** Active and evolving; Argo CD is the documented primary GitOps path. Flux and Talos content is experimental or incomplete.
- **Physical platforms:** Hetzner-hosted servers and storage are represented in inventory and configuration. A 16U mini-rack and external NAS are proposed; their exact hardware and deployment status require confirmation.
- **Logical platforms:** Single-node K3s on a Hetzner VPS; Argo CD-managed applications; Ansible-managed Linux hosts; NixOS experiments.
- **Core services:** Argo CD, Cilium, CoreDNS, Envoy Gateway, cert-manager, ExternalDNS, External Secrets with 1Password Connect, Cloudflare Tunnel, Tailscale, SMB CSI storage, Crossplane, and Mailpit.
- **Open decisions:** Confirm the on-premises rack bill of materials, external NAS platform, authoritative backup targets and retention, and whether Flux, Talos, Terraform, or OpenTofu graduate from experimental status.
- **Next milestone:** Validate this baseline against the running environment, complete the inventory, and publish tested backup and recovery runbooks.

For detail, use the [documentation index](docs/README.md), [roadmap](ROADMAP.md), and [ADRs](adr/README.md).
