# Shared PostgreSQL

`kubernetes/argo/manifests/postgres-operator.yaml` defines the Zalando operator
and UI Helm Applications, pinned to chart version `1.15.1`. Both use the
`postgres-operator` namespace. The operator watches the `postgres` namespace.

`kubernetes/argo/manifests/postgres.yaml` defines `cluster01`: one PostgreSQL 17
instance with one `10Gi` `hcloud-volumes` volume. Homarr, Vikunja, and Vaultwarden
have separate prepared databases and owner credentials on that instance.

The separate Authentik `cluster00` definition and its PushSecret are preserved
in `kubernetes/argo/not-deployed/postgres-authentik.yaml`. They are excluded from
this setup and still require a storage review before deployment.

## Deploy through Argo CD

The `homelab-manifest` ApplicationSet explicitly includes `postgres-operator.yaml`
and `postgres.yaml`. Its generated parents are `postgres-operator.manifest` and
`postgres.manifest`. Publish the reviewed changes to the Git revision Argo CD
watches before refreshing the ApplicationSet.

1. Sync `postgres-operator.manifest`, then the `postgres-operator` and
   `postgres-operator-ui` Helm Applications. Wait for the operator Deployment and
   its CRDs to become ready. The Helm Application manages the CRDs using
   server-side apply; the operator's own CRD registration is disabled.
2. Sync `postgres.manifest`. The separate parent Applications do not provide a
   readiness dependency between the operator and PostgreSQL resources. If the
   initial PostgreSQL sync ran before the CRDs existed, repeat it after the
   operator becomes ready.
3. Verify the database and credential publishing without displaying secrets:

   ```sh
   mise x -- kubectl get postgresql cluster01 -n postgres
   mise x -- kubectl get pods,pvc,services -n postgres
   mise x -- kubectl get pushsecret -n postgres
   ```

The operator creates the primary Service `cluster01.postgres.svc.cluster.local`
on port `5432`. Applications connect through this Service, rather than mounting
the database volume.

The PushSecrets publish these 1Password items through the existing `1password`
ClusterSecretStore:

| Database | Item | Fields |
| --- | --- | --- |
| Homarr | `postgres.cluster01.homarr.owner` | `username`, `password` |
| Vikunja | `postgres.cluster01.vikunja.owner` | `username`, `password` |
| Vaultwarden | `postgres.cluster01.vaultwarden.owner` | `username`, `password` |

Wait for PostgreSQL and its PushSecrets to be healthy before switching consuming
applications. Existing SQLite databases require a separate data migration.

## Operator UI

The `postgres-operator-ui-tailscale` Ingress routes HTTPS from the tailnet to the
UI's ClusterIP Service, `postgres-operator-ui:80`. Its Tailscale hostname is
`postgres-operator` and Funnel is disabled. No NetworkPolicies are added.

Find the assigned hostname after the Tailscale operator reconciles the Ingress:

```sh
mise x -- kubectl get ingress postgres-operator-ui-tailscale -n postgres-operator
```

Open `https://postgres-operator.<tailnet>.ts.net/` using that assigned tailnet
suffix. The UI manages PostgreSQL cluster resources; it is not a SQL client.
Keep lasting configuration changes in Git, since Argo CD can reconcile UI edits
back to the manifests.

## Storage lifecycle

The cluster resource has Argo CD prune protection. The operator is configured
not to delete database PVCs when a cluster is deleted, and `hcloud-volumes` has
the `Retain` reclaim policy. Retained cloud volumes remain billable until
explicitly retired.

To grow the database volume, increase `cluster01.spec.volume.size` in
`postgres.yaml` and sync it. The operator uses PVC expansion; the StorageClass
must permit expansion. Backups and restore testing are a separate requirement.

## References

- [Zalando operator quickstart](https://opensource.zalando.com/postgres-operator/docs/quickstart.html)
- [Zalando operator UI](https://opensource.zalando.com/postgres-operator/docs/operator-ui.html)
- [Tailscale Kubernetes ingress](https://tailscale.com/docs/kubernetes-operator/ingress)
