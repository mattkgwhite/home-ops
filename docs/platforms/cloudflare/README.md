# Cloudflare Platform

## Architecture overview

Cloudflare is used by ExternalDNS, cert-manager DNS challenges, and Cloudflare
Tunnel. Credentials are referenced through External Secrets and 1Password.

## Configuration overview

DNS, certificate, and tunnel resources are Argo-managed Kubernetes manifests.
The repository must contain no plaintext API tokens or tunnel credentials.

## Deployment notes

Create least-privilege credentials outside Git, store them in 1Password, and
verify ExternalSecret names and zone filters before sync.

## Upgrade procedure

Review release notes, rotate tokens independently of upgrades, then validate
DNS reconciliation, certificate renewal, and tunnel health.

## Troubleshooting

Check ExternalSecret readiness, token permissions, zone filters, controller
logs, certificate challenges, and Cloudflare-side tunnel status.

## Live configuration

- [ExternalDNS](../../../kubernetes/argo/manifests/external-dns.yaml)
- [cert-manager](../../../kubernetes/argo/manifests/cert-manager.yaml)
- [Cloudflare Tunnel](../../../kubernetes/argo/manifests/cloudflared.yaml)
