# Networking Platform

## Architecture overview

Cilium provides Kubernetes networking and load-balancer address management.
Envoy Gateway implements Gateway API. ExternalDNS integrates with Cloudflare;
Cloudflare Tunnel and Tailscale provide external and private paths. UniFi and
the physical VLAN design are proposed, not represented as live configuration.

## Configuration overview

Cluster networking is declared in the Argo manifests for `kube-system`,
`gateway`, `envoy-gateway`, `external-dns`, `cloudflared`, and `tailscale`.

## Deployment notes

Install CRDs before custom resources. Confirm DNS zones, address pools,
certificate references, and exposure intent before syncing.

## Upgrade procedure

Upgrade CRDs and controllers in upstream order, validate Gateway API
compatibility, then test DNS, public ingress, and private access.

## Troubleshooting

Inspect Cilium status, endpoints, Gateway conditions, certificate readiness,
DNS records, and tunnel/operator logs.

## Live configuration

- [Cilium and CoreDNS](../../../kubernetes/argo/manifests/kube-system.yaml)
- [Gateway](../../../kubernetes/argo/manifests/gateway.yaml)
- [Envoy](../../../kubernetes/argo/manifests/envoy-gateway.yaml)
- [ExternalDNS](../../../kubernetes/argo/manifests/external-dns.yaml)
- [Cloudflare Tunnel](../../../kubernetes/argo/manifests/cloudflared.yaml)
- [Tailscale](../../../kubernetes/argo/manifests/tailscale.yaml)
