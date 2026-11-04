# RustFS

`kubernetes/argo/manifests/rustfs.yaml` deploys RustFS in the `rustfs` namespace
through the upstream Helm chart at the source commit for release `1.0.4`. The
container image is explicitly pinned to `rustfs/rustfs:1.0.4` because the bundled
chart advertises an older application version.

The deployment runs one standalone instance with a `Recreate` update strategy and
one `20Gi` `hcloud-volumes` PVC. RustFS writes its own logs to stdout, so the chart
does not allocate a second volume for logs. Standalone mode has no RustFS-level
disk or node redundancy; plan a migration before changing to a distributed
topology.

## Credentials and activation

Create a 1Password item named `rustfs` in the vault used by the existing
`1password` ClusterSecretStore, with two non-default fields:

| Property | Kubernetes Secret key |
| --- | --- |
| `access_key` | `RUSTFS_ACCESS_KEY` |
| `secret_key` | `RUSTFS_SECRET_KEY` |

The ExternalSecret creates `rustfs-credentials` in the `rustfs` namespace. The
access key and secret key also serve as the initial console login credentials.
Use application-specific credentials for consumers after configuring them in the
console.

The `homelab-manifest` ApplicationSet includes `rustfs.yaml`. Publish the reviewed
changes to the Git revision Argo CD tracks, then sync the ApplicationSet and its
generated `rustfs.manifest` parent. Its first waves create the namespace and
credentials; the child `rustfs` Application deploys the chart. Create the 1Password
item before syncing so credential readiness does not hold up the parent sync.

The PVC stays in the same sync wave as the workload because `hcloud-volumes` uses
`WaitForFirstConsumer`. An earlier wave would wait for binding before the pod
needed to trigger that binding exists. The PVC is managed outside the chart,
with `Prune=false,Delete=false`, and the storage class has a `Retain` reclaim
policy. Retained cloud volumes remain billable.

To expand capacity, increase the PVC's requested storage in `rustfs.yaml` and
sync its parent. Increasing the claim does not convert standalone storage into
distributed storage. A bound claim's storage class cannot be changed in place.

## Access

| Use | Endpoint |
| --- | --- |
| S3 from workloads | `http://rustfs-svc.rustfs.svc.cluster.local:9000` |
| Console through Tailscale | `https://rustfs.<tailnet>.ts.net/` |
| S3 through Tailscale | `https://rustfs-s3.<tailnet>.ts.net/` |

Use the actual Tailscale hostnames assigned to the two Ingress resources. Funnel
is disabled. S3 clients should use path-style bucket addressing and region
`us-east-1`, matching the chart's region default. TLS terminates at the Tailscale
proxy; its connection to the ClusterIP backend uses HTTP.

The NetworkPolicy allows console and S3 connections from proxies in `tailscale`,
and S3 connections from `observability` and pods in `rustfs`. Add explicit client
namespaces to that policy when connecting other applications. RustFS's outbound
traffic is restricted to cluster DNS; remote replication, tiering, OIDC, and
external telemetry need their corresponding network access before enabling them.

The chart creates a dedicated ServiceAccount with token automounting disabled.
Resource limits, health probes, a non-root security context, and a writable
temporary directory are configured. A namespace LimitRange supplies resource
defaults for the chart's init container, which has no resource-values setting.

## Verification

```sh
mise x -- kubectl get externalsecret rustfs-credentials -n rustfs
mise x -- kubectl get applications rustfs.manifest rustfs -n argocd
mise x -- kubectl get pods,pvc,service,ingress -n rustfs
mise x -- kubectl rollout status deployment/rustfs -n rustfs
```

Confirm the ExternalSecret is ready, the PVC is bound to `hcloud-volumes`, and
both Ingress resources have Tailscale addresses. Sign in to the console, create
a test bucket, and upload/download a small test object. Check persistence after a
normal rollout before storing important data. Do not print Secret values during
verification.

ExternalSecret refresh does not replace environment variables in an existing
pod. After rotating the 1Password credentials and waiting for the Secret to
refresh, restart the deployment:

```sh
mise x -- kubectl rollout restart deployment/rustfs -n rustfs
mise x -- kubectl rollout status deployment/rustfs -n rustfs
```

## Storage compatibility

The Storage Box SMB class is not used: RustFS's startup guard classifies CIFS/SMB
as unsupported, and its disk replacement code uses OS file locks. S3 object
locking is a separate feature and does not remove those filesystem requirements.

This deployment creates its own object store on the PVC. It does not mount or
proxy an existing Hetzner Object Storage bucket. Loki can later use its S3
endpoint, but Loki's configuration and retention settings are managed separately.
The 20 GiB claim is for evaluation and has not been sized for 180 days of logs
or metrics.

## References

- [RustFS Kubernetes deployment](https://docs.rustfs.com/en/installation/cloud-native)
- [RustFS 1.0.4 chart metadata](https://raw.githubusercontent.com/rustfs/rustfs/1.0.4/helm/rustfs/Chart.yaml)
- [Unsupported filesystem guard](https://raw.githubusercontent.com/rustfs/rustfs/1.0.4/rustfs/src/startup_fs_guard.rs)
- [Disk replacement locking](https://raw.githubusercontent.com/rustfs/rustfs/1.0.4/crates/ecstore/src/disk/local/replacement_lease.rs)
