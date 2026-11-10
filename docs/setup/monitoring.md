# Monitoring

`kubernetes/argo/manifests/monitoring.yaml` deploys Grafana, kube-prometheus-stack,
Loki, and Fluent Bit in `observability`. The `homelab-manifest` ApplicationSet
includes it. Publishing the manifests to its tracked Git revision allows Argo CD
to provision the configured volumes.

## Access and credentials

Grafana is exposed privately at `https://grafana.<tailnet>/` through
Tailscale Ingress, with Funnel disabled. The Ingress address after reconciliation
is authoritative. Prometheus, Alertmanager, and Loki remain internal services;
Grafana queries their cluster endpoints.

Local administrator login is enabled for evaluation. Create a 1Password item
named `grafana` in the vault used by the `1password` ClusterSecretStore, with an
`admin_password` field containing a strong generated password. The ExternalSecret
creates `grafana-admin`; sign in as `admin`. The placeholder Authentik integration
is disabled. Configuring SSO later requires the real provider URLs, client
credentials, and Grafana callback URL.

Grafana uses the `grafana` database on the existing `cluster01` PostgreSQL cluster.
`postgres.yaml` declares the prepared database and its `public` schema. The
operator generates the owner credentials, which the PushSecret publishes to
`postgres.cluster01.grafana.owner` in 1Password. An ExternalSecret copies the
username and password into `grafana-postgres` in `observability`.

Sync `postgres.manifest` before monitoring, then wait for the database credentials
and the two Grafana ExternalSecrets to become ready. PostgreSQL connections use
TLS with `sslmode=require`, matching the cluster's self-signed certificate.

## Storage and retention

| Component | Storage | Purpose | Retention |
| --- | --- | --- | --- |
| Grafana | Existing PostgreSQL volume | Users, dashboards, data source settings | Managed in Grafana |
| Prometheus | 10 GiB `hcloud-volumes` RWO PVC | Metric samples and WAL | 30 days |
| Loki | 20 GiB `hcloud-volumes` RWO PVC | Log chunks, TSDB indexes, WAL, compactor state | 30 days |
| Alertmanager | 10 GiB `hcloud-volumes` RWO PVC | Silences and notification state | Chart default of 120 hours |

The manifests request **40 GiB of additional cloud volume capacity**, separate
from PostgreSQL and RustFS. This is billed for provisioned capacity, even when
partially filled; use the current volume rate in your Hetzner project for the
monthly cost. RustFS and Storage Box SMB are not used by this layout.

Grafana has persistence explicitly disabled because its database lives in
PostgreSQL. Its local plugin files are ephemeral, so declare plugins in Helm
instead of relying on manual installation. Loki's optional Memcached caches are
disabled for this single-instance layout.

Prometheus removes expired metric blocks. Loki's singleton compactor applies
`720h` retention with a 24-hour TSDB index period and deletes expired chunks in
the background. Loki permits queries spanning 30 days. Deletion is asynchronous,
so data is not guaranteed to disappear at the exact retention boundary.

These capacities are starting allocations, not a guarantee that 30 days will
fit. Monitor actual ingestion and free space and expand before running out of
space. Prometheus has no size-based retention cap that would silently shorten
the requested history. Loki's filesystem backend does not automatically delete
newer data when its volume fills.

Retained data at the same ingestion rate is roughly proportional to retention
duration, but WAL, indexes, compaction workspace, and the minimum provisioned
volume sizes prevent an exact sixfold reduction from 180 to 30 days. Measure
actual stored growth after ingestion starts before treating this budget as
sufficient.

The storage class supports expansion and retains released volumes. Loki's
automatic PVC deletion on scale-down or StatefulSet deletion is disabled.
Neither persistence nor retention replaces backups. A future storage-class or
backend change needs a data migration. For StatefulSet claims, increasing the
chart value alone may fail because claim templates are immutable; expand the
bound PVCs and reconcile the owning workload as part of a planned resize.

## Verification

After publishing and syncing the reviewed configuration:

```sh
mise x -- kubectl get externalsecret -n observability
mise x -- kubectl get pushsecret cluster01.grafana.owner -n postgres
mise x -- kubectl get applications grafana kube-prometheus-stack loki fluentbit -n argocd
mise x -- kubectl get pods,pvc,ingress -n observability
mise x -- kubectl rollout status deployment/grafana -n observability
```

Confirm all three monitoring PVCs are bound to `hcloud-volumes`. Log into Grafana,
check both data sources, then query a node metric, a pod metric, and recent pod
logs. Kubelet/cAdvisor scraping is enabled for pod resource metrics. The namespace
permits the host access needed by node exporter and Fluent Bit on Talos.

Grafana reads database credentials from environment variables at startup. After
database credential rotation, wait for the ExternalSecret to refresh and restart
Grafana. The initial admin password is stored in PostgreSQL after first startup;
changing its bootstrap Secret alone does not reset an existing Grafana password.

## References

- [Tailscale Kubernetes Ingress](https://tailscale.com/docs/kubernetes-operator/ingress)
- [Grafana database configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/#database)
- [Prepared PostgreSQL databases](https://postgres-operator.readthedocs.io/en/latest/user/#prepared-databases)
- [Prometheus storage and retention](https://prometheus.io/docs/prometheus/latest/storage/)
- [Loki retention](https://grafana.com/docs/loki/latest/operations/storage/retention/)
