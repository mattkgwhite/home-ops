# Tailscale exit node

`kubernetes/argo/manifests/tailscale.yaml` declares the cluster-scoped
`tailscale-exit-node` Connector. The existing Tailscale operator provisions one
exit-node device named `homelab-exit-node`, tagged `tag:k8s`, with its workload in
the `tailscale` namespace. The Connector uses the operator's existing OAuth
credentials from External Secrets.

Only `exitNode: true` is configured. It does not advertise Pod, Service, or LAN
subnets. Internet traffic from clients that select this exit node leaves through
the cluster's normal internet egress path.

## Deploy through Argo CD

The existing `homelab-manifest` ApplicationSet discovers `tailscale.yaml` and
creates `tailscale.manifest`. Once this change is published to `main`, that
Application automatically syncs the Connector. The `tailscale` Helm Application
continues to manage the operator and its CRDs.

The Connector skips Argo CD's dry-run only when its CRD is missing, because the
operator's separate Helm Application installs that CRD. The operator must be
installed and healthy before the Connector can reconcile.

Check the Applications, Connector, and generated workload:

```sh
mise x -- kubectl get applications tailscale.manifest tailscale -n argocd
mise x -- kubectl get connector tailscale-exit-node
mise x -- kubectl get connector tailscale-exit-node -o yaml
mise x -- kubectl get pods -n tailscale
```

## Approve and use the exit node

1. In the Tailscale admin console, find `homelab-exit-node`, open **Edit route
   settings**, and enable **Use as exit node**, unless an existing
   `autoApprovers.exitNode` policy already approves `tag:k8s`.
2. If your tailnet uses a custom access policy, ensure intended users have access
   to `autogroup:internet`. Permission to connect to the exit-node device itself
   does not grant permission to use it for internet traffic.
3. On each client, select `homelab-exit-node` from the Tailscale app's exit-node
   menu. Enable **Allow LAN access** if that client needs its local network.
4. Check the client's public IP address and confirm it matches the cluster's
   internet egress address. To stop routing through it, select **None** in the
   client's exit-node menu.

## References

- [Connector capabilities](https://tailscale.com/docs/kubernetes-operator/connector)
- [Deploy exit nodes and subnet routers](https://tailscale.com/docs/kubernetes-operator/connector/deploy-subnet-router)
- [Exit-node approval and client configuration](https://tailscale.com/docs/features/exit-nodes)
- [Connector CRD for the pinned operator release](https://raw.githubusercontent.com/tailscale/tailscale/v1.104.4/cmd/k8s-operator/deploy/crds/tailscale.com_connectors.yaml)
- [Argo CD dry-run behavior for custom resources](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/#skip-dry-run-for-new-custom-resources-types)
