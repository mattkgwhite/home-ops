# System Context

The operator maintains desired state in this repository. GitHub hosts the
repository and dependency automation. Argo CD reads Kubernetes manifests and
Helm application definitions. Ansible connects to Linux hosts using addresses
resolved from 1Password.

Cloudflare provides DNS and tunnel integration. Tailscale provides private
access paths. Hetzner hosts compute and a Storage Box used through SMB.
1Password is the external secret system.

## Trust boundaries

- Public ingress terminates through Kubernetes gateway configuration.
- Private routes use Tailscale resources.
- Cloud tokens enter the cluster through External Secrets.
- Git contains secret references and encrypted-file tooling, not plaintext
  credentials.

TODO: Add a verified, sanitised data-flow diagram with public ingress, VLANs,
DNS zones, and recovery paths.
