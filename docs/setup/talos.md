# Talos

## Structure

| Nodes | Type | Configuration |
|---|---|---|
| Athena | VPS - Worker | 8c/16GB /w 160GB |
| Electra | VPS - Control Plane | 2c/4GB /w 40GB |

## Cluster networking

The live `olumpus` configuration was checked on 2026-10-17:

| Network | Range or address |
|---|---|
| Cluster pods | `10.244.0.0/16` |
| Control-plane pods (`talos-iwd-lqp`) | `10.244.1.0/24` |
| Worker pods (`talos-oc7-jd1`) | `10.244.0.0/24` |
| Kubernetes Services | `10.96.0.0/12` |
| Cluster DNS Service | `10.96.0.10` |

Public node addresses are represented by placeholders throughout this document:

| Placeholder | Node |
|---|---|
| `control-plane-ip` | `talos-iwd-lqp` |
| `worker-ip` | `talos-oc7-jd1` |

Replace these placeholders with the corresponding node's current public IPv4 address when configuring firewall rules or interpreting packet captures. A `/32` suffix restricts a firewall source to that single address.

The `10.42` and `10.43` references in older configurations belong to the K3s setup. They do not describe this Talos cluster. Cilium's LoadBalancer IP pool is also separate from the pod and Service networks.

Talos bootstrap CoreDNS is disabled in the machine configuration, but its existing Deployment remains. Argo CD manages CoreDNS through `kubernetes/argo/manifests/kube-system.yaml`. When adopting that Deployment, retain its immutable selector:

```yaml
service:
  selector:
    k8s-app: kube-dns
deployment:
  selector:
    matchLabels:
      k8s-app: kube-dns
```

Without these overrides, the Helm Service can select labels missing from the bootstrap pods while the Deployment cannot adopt a different immutable selector. An empty DNS EndpointSlice then prevents Argo CD from reaching its repository server to finish reconciling.

### Recover an empty DNS Service

Run from the repository root. These commands change the live cluster.

1. Update only the CoreDNS Application from the corrected file:

   ```zsh
   mise x -- yq 'select(.kind == "Application" and .metadata.name == "coredns")' kubernetes/argo/manifests/kube-system.yaml | mise x -- kubectl apply -f -
   ```

2. Restore the live Service selector to break the Argo CD/DNS dependency:

   ```zsh
   mise x -- kubectl patch service kube-dns -n kube-system --type=json -p='[{"op":"replace","path":"/spec/selector","value":{"k8s-app":"kube-dns"}}]'
   mise x -- kubectl get endpointslices -n kube-system -l kubernetes.io/service-name=kube-dns -o yaml
   ```

   Continue only when at least one endpoint has `ready: true`.

3. Restart the repository server and refresh CoreDNS:

   ```zsh
   mise x -- kubectl rollout restart deployment/argocd-repo-server -n argocd
   mise x -- kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=180s
   ```

   Continue only if the rollout succeeds:

   ```zsh
   mise x -- kubectl annotate application coredns -n argocd argocd.argoproj.io/refresh=hard --overwrite
   mise x -- kubectl get application coredns -n argocd -w
   ```

   After reconciliation, verify the CoreDNS rollout and endpoint readiness. Persist the repository change in the Git source used by Argo CD before reapplying older manifests.

### Inter-node transport: UDP 4789

During the initial recovery on 2026-10-17, both nodes still had a `flannel.1` VXLAN interface using VNI `1`, UDP destination port `4789`, and the public `enp1s0` interface. Their remote pod-subnet routes used that interface even though Cilium was configured for native routing. That transitional configuration depended on leftover Flannel state. The subsequent Talos upgrade reboot removed it; the repair described below configures Cilium to own the VXLAN transport on the same port.

VXLAN wraps the original pod Ethernet frame inside an outer UDP packet. TCP and UDP application traffic can both travel inside it. For example:

```text
Worker Tailscale pod -> control-plane CoreDNS pod, inner UDP port 53
  outer packet: worker-ip -> control-plane-ip, UDP destination 4789

Control-plane External Secrets pod -> worker 1Password Connect pod, inner TCP port 8080
  outer packet: control-plane-ip -> worker-ip, UDP destination 4789
```

Other connections between pods on different nodes, such as Argo CD to Redis on TCP `6379`, also depend on this transport when their routes use `flannel.1`. API reply traffic routed back to a remote pod subnet can depend on it too. Connections between local pods do not need the inter-node tunnel.

The firewall sees the outer node public addresses and UDP port `4789`, not the inner pod addresses or application port. Allowing inbound DNS port `53` therefore does not allow DNS carried inside VXLAN. VXLAN provides encapsulation, not encryption; it does not add confidentiality to inner application traffic.

Required inbound allowances for the shared Hetzner Cloud Firewall:

| Source | Protocol | Destination port | Purpose |
|---|---|---|---|
| `worker-ip/32` | TCP | `6443` | Worker host access to the control-plane Kubernetes API |
| `control-plane-ip/32` | TCP | `10250` | Control-plane access to the worker kubelet, including pod logs and exec |
| `control-plane-ip/32` | TCP | `50000` | Control-plane access to the worker Talos API |
| `control-plane-ip/32`, `worker-ip/32` | UDP | `4789` | VXLAN traffic in both directions between the nodes |

These are inter-node allowances, not a complete firewall policy. Retain existing administrator and application access rules. If unrestricted outbound TCP and UDP rules already exist for IPv4 and IPv6, an additional outbound UDP `4789` rule is redundant. With restricted outbound rules, allow UDP destination `4789` to the peer node public addresses. Hetzner combines allow rules; a specific rule does not override a deny rule or give higher priority than another allow rule.

Before the UDP allowance, simultaneous packet captures showed outgoing VXLAN packets on both nodes without corresponding incoming packets on the peer. External Secrets logged DNS failures and timeouts reaching 1Password Connect. After the allowance, all five ExternalSecrets reached `SecretSynced` with `Ready=True`. `SecretSyncedError` is a general reconciliation failure, so inspect current conditions and events rather than assuming every future occurrence has this cause.

Verify synchronisation without reading Secret values:

```zsh
mise x -- kubectl get externalsecrets -A
mise x -- kubectl get clustersecretstore 1password
mise x -- kubectl get pods -A
```

Keep UDP `4789` allowed between the node public addresses. Cilium's default VXLAN port is `8472`, but this cluster explicitly configures `tunnelPort: 4789` to use the established firewall allowance. The current configuration creates `cilium_vxlan` and does not depend on the old `flannel.1` interface.

References: [Flannel VXLAN backend](https://github.com/flannel-io/flannel/blob/master/Documentation/backends.md), [Cilium routing modes and default tunnel ports](https://docs.cilium.io/en/stable/network/concepts/routing/), [Hetzner firewall behavior](https://docs.hetzner.com/cloud/firewalls/faq/).

### Hetzner Cloud instance metadata

Hetzner Cloud exposes its instance metadata service at the link-local address `169.254.169.254`. The CSI driver uses metadata to discover the server it runs on, including its instance ID. The `169.254.169.254/32` CIDR matches that single destination address.

| Destination | Protocol | Destination port | Purpose |
|---|---|---|---|
| `169.254.169.254/32` | TCP | `80` | Hetzner Cloud instance metadata over HTTP |

When restricting CSI pod egress, include this rule under the NetworkPolicy's `spec.egress`, as in [the hcloud CSI manifest](../../kubernetes/argo/manifests/hcloud.yaml):

```yaml
- to:
    - ipBlock:
        cidr: 169.254.169.254/32
  ports:
    - protocol: TCP
      port: 80
```

The instance ID endpoint is `http://169.254.169.254/hetzner/v1/metadata/instance-id`. This egress allowance permits metadata discovery; it does not create a route or provide the Cloud API token.

Reference: [Hetzner Cloud server metadata](https://docs.hetzner.cloud/reference/cloud#server-metadata).

### Resolver files and firewalls

Keep CoreDNS's explicit upstreams (`forward . 8.8.8.8 8.8.4.4`). `/run/systemd/resolve/resolv.conf` was a workaround for the former Ubuntu/K3s setup and must not be restored on Talos. Talos has `/etc/resolv.conf`, but its host loopback resolver cannot be used by mounting that file into an ordinary pod.

Sidero documents a separate incompatibility between Talos `machine.features.hostDNS.forwardKubeDNSToHost: true` and Cilium `bpf.masquerade: true`. Both were enabled when checked. Disabling forwarding is a documented compatibility workaround, but it does not repair an empty DNS Service or establish that pod-to-API routing works. See [Talos Cilium known issues](https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium).

Hetzner Cloud Firewalls do not filter private Cloud Network traffic. Public inter-node traffic is subject to the firewall; the required rules depend on the actual routing or encapsulation used. Allowing inbound port 53 from pod or Service CIDRs does not fix a Service with no endpoints. If custom outbound rules exist, allow TCP and UDP port 53 to the configured external resolvers. See [Hetzner firewall FAQ](https://docs.hetzner.com/cloud/firewalls/faq/).

DNS Service selection and inter-node transport were separate faults. After restoring both, verify that worker pods can reach DNS and the API without control-plane placement workarounds.

### Repeated DNS rollouts and remote-node API access

Two additional problems were observed on 2026-10-17 after secret synchronisation recovered:

1. Argo CD repeatedly switched CoreDNS between ReplicaSets whose templates differed only in the name of a container port numbered `53`. The inherited TCP/UDP port list and client-side apply were not converging. With one replica and `maxUnavailable: 1`, every replacement temporarily removed the only ready DNS endpoint. During a subsequent ready period, CoreDNS logged successful answers to Tailscale's `kubernetes.default.svc.cluster.local` queries. The repository now enables `ServerSideApply=true` for the CoreDNS Application and uses `rollingUpdate.maxUnavailable: 0` with `maxSurge: 1`. After applying the changes, CoreDNS became `Synced`, retained the correct TCP/UDP port names, and stopped alternating ReplicaSets during the recovery checks. See [Argo CD server-side apply](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/#server-side-apply).

2. Simultaneous captures on the public interfaces showed worker pod traffic such as `10.244.0.232 -> control-plane-ip:6443` leaving the worker without appearing at the control plane. Connections sourced from the worker public address did reach the API. This is consistent with private pod source addresses being filtered on the public network path. Cilium BPF masquerading excludes remote cluster nodes by default. This cluster registers its public node addresses as Kubernetes `InternalIP` addresses, so the repository enables the installed agent's supported `enable-remote-node-masquerade` setting through Helm `extraConfig`:

   ```yaml
   bpf:
     masquerade: true
   extraConfig:
     enable-remote-node-masquerade: "true"
   ```

   This setting translates pod source addresses to the local node address for traffic to a remote node. It does not change pod-to-pod VXLAN transport or remove the UDP `4789` requirement. The remote API connection is then sourced from `worker-ip` rather than a `10.244.0.x` pod address. The installed agent flag, rendered ConfigMap, and API-server dry-run were checked. After applying the Applications and rolling Cilium, the CA injector updated the webhook CA bundles, External DNS completed repeated successful record synchronisations, and the Tailscale operator started its controllers. The worker NAT table also showed API reply translations back to worker pods. See [Cilium remote-node masquerading](https://docs.cilium.io/en/stable/network/concepts/masquerading/).

Apply only the two corrected Applications from the repository root:

```zsh
mise x -- yq 'select(.kind == "Application" and (.metadata.name == "coredns" or .metadata.name == "cilium"))' kubernetes/argo/manifests/kube-system.yaml | mise x -- kubectl apply -f -
mise x -- kubectl annotate application coredns cilium -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

After Cilium has synced, confirm the live ConfigMap contains the setting before restarting its agents:

```zsh
mise x -- kubectl get configmap cilium-config -n kube-system -o 'jsonpath={.data.enable-remote-node-masquerade}{"\n"}'
```

Continue only when the value is `true`. Restarting the DaemonSet rolls the networking agents across both nodes and can briefly interrupt traffic:

```zsh
mise x -- kubectl rollout restart daemonset/cilium -n kube-system
mise x -- kubectl rollout status daemonset/cilium -n kube-system --timeout=300s
mise x -- kubectl rollout status deployment/coredns -n kube-system --timeout=180s
```

After both rollouts succeed, verify that worker controllers stop logging API timeouts and that CoreDNS no longer alternates ReplicaSets. Do not treat a momentary `1/1 Running` status as proof that a restarting controller has recovered.

### Talos upgrade reboot exposed missing pod routes

After both nodes rebooted for a Talos upgrade on 2026-10-17, Tailscale proxies repeatedly exited while resolving `kubernetes.default.svc` through `10.96.0.10`. CoreDNS was ready, its Service selector was correct, and its EndpointSlice had a ready endpoint. A diagnostic pod on the control plane could resolve Kubernetes names, while a worker diagnostic pod timed out against both the DNS Service and the CoreDNS pod address directly.

The reboot had removed `flannel.1`. Cilium remained in native routing mode with `autoDirectNodeRoutes: false` and no replacement pod-subnet routing. Route lookups for remote pod addresses selected the public internet default gateway. Opening more application ports could not repair that missing route.

The Cilium Application in `kubernetes/argo/manifests/kube-system.yaml` now configures:

```yaml
routingMode: tunnel
tunnelProtocol: vxlan
tunnelPort: 4789
loadBalancer:
  algorithm: maglev
  mode: snat
```

Cilium manages the inter-node tunnel and recreates `cilium_vxlan` when its agents start. UDP destination `4789` must remain allowed between `control-plane-ip` and `worker-ip`. SNAT replaces the former DSR load-balancing mode because DSR is unsupported with VXLAN tunnelling. The previous DNS selector, server-side apply, rollout availability, and remote-node masquerading fixes remain in place. See [Cilium routing requirements](https://docs.cilium.io/en/stable/network/concepts/routing/) and [Cilium DSR routing compatibility](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/).

The installed Cilium chart was rendered and server-side dry-run checked before applying the corrected Application and ConfigMap, then rolling its DaemonSet. The direct ConfigMap application broke the dependency on Argo CD controllers that could not reach services across nodes. Cilium subsequently reported `Synced`, and diagnostic pods on both nodes resolved Kubernetes names. The worker also resolved external names through CoreDNS, and the existing Tailscale proxies recovered on their next retry.

Check the live configuration and worker-side DNS after an upgrade:

```zsh
mise x -- kubectl get configmap cilium-config -n kube-system -o 'jsonpath={.data.routing-mode}{" "}{.data.tunnel-protocol}{" "}{.data.tunnel-port}{" "}{.data.bpf-lb-mode}{"\n"}'
mise x -- kubectl get pods -n tailscale -o wide
mise x -- kubectl exec -n tailscale tailscale-gateway-0 -- timeout 8 nslookup kubernetes.default.svc.cluster.local 10.96.0.10
mise x -- kubectl exec -n tailscale tailscale-gateway-0 -- timeout 8 nslookup api.cloudflare.com 10.96.0.10
```

Expect `tunnel vxlan 4789 snat`, and successful DNS answers. Confirm that the chosen proxy is on the worker when testing the cross-node path to CoreDNS. Keep the corrected Application in the Git source used for future reconciliation. A full node reboot has not been repeated as part of this repair.

The intended Tailscale `1.104.1` change was present on GitHub while the live Application and containers were still on `1.102.4`. ApplicationSet reconciliation itself was failing on cluster DNS, so the restart log was not evidence of a `1.104.1` regression. The Tailscale Application was updated separately after restoring connectivity. Its operator and all three proxy pods then ran `1.104.1`, the ProxyGroup reported ready, the OAuth ExternalSecret returned to `SecretSynced`, and Argo CD returned HTTP `200` over the tailnet with successful TLS verification. Check the live Application version and container images independently of a Git commit. Once DNS recovered, the ApplicationSet again reported the duplicate-name defect described below; its corrected configuration provides the GitOps management path for these fixes.

At the final recovery checks, all four upgraded Tailscale pods had been running for at least 24 minutes with zero restarts and no replacements since the recorded baseline. The Tailscale Application was `Synced` and `Healthy` after correcting OAuth Secret ownership, and the existing OAuth Secret retained its UID. The temporary diagnostic pods were removed.

### Tailscale gateway Pod Security requirement

After network recovery, the operator could create its gateway StatefulSet, but Talos's default baseline Pod Security policy rejected the proxy pods because their `sysctler` and `tailscale` containers are privileged. The default kernel-mode proxies need these permissions for their tunnel device and network setup. The namespace in `kubernetes/argo/manifests/tailscale.yaml` therefore contains this exception:

```yaml
metadata:
  name: tailscale
  labels:
    pod-security.kubernetes.io/enforce: privileged
```

The exception is limited to the `tailscale` namespace. After applying it and triggering the gateway StatefulSet to retry, both gateway pods became ready and the `tailscale-gateway` ProxyGroup reported `ProxyGroupReady=True`. See [Tailscale proxy security requirements](https://tailscale.com/docs/kubernetes-operator/reference/rbac).

For subsequent repairs, use the repository's actual checkout path when extracting Application manifests. A failed `yq` file lookup sends no objects to `kubectl apply`; refreshing Applications or restarting Cilium afterward does not install the missing settings. Check that `cilium-config` reports `enable-remote-node-masquerade: "true"` before rolling the agents. Preserve these manifest changes in the Git source used for future deployments.

### Tailscale OAuth Secret ownership

The operator chart's `oauth.clientId` and `oauth.clientSecret` fields accept credential strings, not nested Kubernetes Secret references. Supplying `secret.name` and `secret.key` objects there caused Helm to render its own `operator-oauth` Secret while the `tailscale-oauth` ExternalSecret also managed that resource. Argo CD repeatedly reported the Secret out of sync and reapplied it.

The Tailscale Application now omits those Helm OAuth overrides. The chart still mounts the existing `operator-oauth` Secret, while External Secrets supplies its contents from 1Password. The ExternalSecret target template carries these annotations:

```yaml
target:
  name: operator-oauth
  creationPolicy: Owner
  template:
    metadata:
      annotations:
        argocd.argoproj.io/sync-options: Prune=false
        argocd.argoproj.io/compare-options: IgnoreExtraneous
```

For an existing installation, apply the ExternalSecret configuration first and verify these annotations on the generated Secret before removing the chart's OAuth overrides. `Prune=false` preserves the Secret when it leaves the chart output; `IgnoreExtraneous` excludes the externally generated resource from the chart Application's overall sync status. The handoff was checked using Secret metadata and controller status without reading credential values. See [Argo CD compare options](https://argo-cd.readthedocs.io/en/stable/user-guide/compare-options/) and [Argo CD sync options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/).

### Argo CD dashboard over Tailscale

The dashboard is available at `https://argo.<tailnet>.ts.net/` while connected to the tailnet. Its active configuration is the `argocd-tailscale` Ingress in `kubernetes/argo/manifests/tailscale.yaml`, with `ingressClassName: tailscale`, hostname `argo`, and backend `argocd-server:80` in the `argocd` namespace. Argo CD has `server.insecure: true`; the Tailscale proxy terminates HTTPS and forwards HTTP to the backend. This Ingress provisions a standalone Tailscale proxy because it has no `tailscale.com/proxy-group` annotation; it does not use the existing `tailscale-gateway` ProxyGroup.

During investigation on 2026-10-17, the Ingress existed in the repository but was absent from the cluster. Consequently, the operator had no Argo endpoint to register or present for device approval. The `homelab-manifest` ApplicationSet reported:

```text
ApplicationSet homelab-manifest contains applications with duplicate name: manifests.manifest
```

Its original template in `kubernetes/argo/manifests/argocd.yaml` used `{{.path.basename}}.manifest`. Every matched file is in the same `manifests` directory, so the generated names collided. The source path also pointed every generated Application at that entire directory. Changing names alone would have left multiple Applications managing the same resources. The corrected ApplicationSet uses the filename for unique names and `directory.include` to give each parent Application ownership of one file, as described below.

To restore only the existing tailnet Ingress, run from the repository root:

```zsh
mise x -- yq 'select(.kind == "Ingress" and .metadata.name == "argocd-tailscale")' kubernetes/argo/manifests/tailscale.yaml | mise x -- kubectl apply -f -
mise x -- kubectl get ingress argocd-tailscale -n argocd -o 'jsonpath={.status.loadBalancer.ingress[0].hostname}{"\n"}'
mise x -- kubectl get pods -n tailscale
```

The hostname is populated after the operator provisions the proxy. The repair created a proxy pod named `ts-argocd-tailscale-<suffix>-0`, which became `1/1 Running` with no restarts. Tailscale reported the device online with no health warnings, and an HTTPS request from the connected client returned HTTP `200` with successful certificate verification. No device approval was blocking access at verification time.

Verify access from a client connected to the tailnet:

```zsh
curl --connect-timeout 10 --max-time 20 -sS -o /dev/null -w 'HTTP %{http_code}\nTLS verification %{ssl_verify_result}\n' 'https://argo.<tailnet>.ts.net/'
```

Replace `<tailnet>` with the suffix reported by the Ingress before running the HTTPS check. Expect `HTTP 200` and `TLS verification 0`. The public Argo HTTPRoute is commented out, and the `argocd-public` DNSEndpoint still references an obsolete public address. That record is separate from the tailnet endpoint. The Ingress is now in the managed Tailscale file; `gateway.yaml` retains the separate public gateway configuration and is excluded from the networking ApplicationSet.

### Persist the fixes through Argo CD

The fixes are defined in the existing repository manifests. Cilium's Helm Application renders its ConfigMap and DaemonSet, so its agents recreate `cilium_vxlan` after restarting. CoreDNS's Application retains its selectors, explicit upstream resolvers, server-side apply, and rollout availability settings. Tailscale's manifest contains the operator Application, namespace Pod Security label, OAuth ExternalSecret policy, ProxyGroup, ProxyClass, and Argo tailnet Ingress.

The `homelab-manifest` ApplicationSet in `kubernetes/argo/manifests/argocd.yaml` manages these two files from GitHub's `main` branch:

| Parent Application | File | Managed configuration |
|---|---|---|
| `kube-system.manifest` | `kubernetes/argo/manifests/kube-system.yaml` | Existing kube-system resources and the Cilium/CoreDNS Helm Applications |
| `tailscale.manifest` | `kubernetes/argo/manifests/tailscale.yaml` | Tailscale resources, operator Helm Application, and Argo tailnet Ingress |

The Git generator explicitly selects these two files. `{{ trimSuffix ".yaml" .path.filename }}.manifest` gives each parent a unique name, and `directory.include: '{{ .path.filename }}'` limits its source to that file. Each parent automatically syncs and self-heals the Git-defined resources. The chart Applications then reconcile the generated workloads and settings. Parent-level pruning is disabled, and ApplicationSet deletion preserves managed resources; the child chart Applications retain their own pruning policies.

Publish the corrected manifests to `main` before enabling the parent Applications. Argo CD reads GitHub, not uncommitted local files. During migration, the parents can be staged without `spec.template.spec.syncPolicy.automated` so that validation against an older Git revision cannot restore the broken routing or OAuth settings.

After publishing the fixes, run from the repository root to activate the repository's automatic-sync policy:

```zsh
mise x -- yq 'select(.kind == "ApplicationSet" and .metadata.name == "homelab-manifest")' kubernetes/argo/manifests/argocd.yaml | mise x -- kubectl apply -f -
mise x -- kubectl annotate applicationset homelab-manifest -n argocd argocd.argoproj.io/application-set-refresh=true --overwrite
mise x -- kubectl get applicationset homelab-manifest -n argocd -o 'jsonpath={.status.conditions}{"\n"}'
mise x -- kubectl get applications kube-system.manifest tailscale.manifest cilium coredns tailscale -n argocd
```

Expect the ApplicationSet's `ErrorOccurred` condition to be `False`, with two generated parents, each including its own file. Verify parent sync and the live networking settings before rebooting a node. Additional applications or the obsolete public gateway are not selected by this ApplicationSet. A cluster rebuild still requires the documented Talos, CNI, DNS, Argo CD, and credential bootstrap steps before GitOps controllers can run.

References: [Git file generator parameters](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/), [Directory file selection](https://argo-cd.readthedocs.io/en/stable/user-guide/directory/).

### Verified recovery

After applying the Cilium/CoreDNS Application corrections and the Tailscale namespace exception on 2026-10-17, a 30-minute observation recorded no restart-count increases and no replacements of existing pods. All containers were ready at the observation checks; the only new pods were the two Tailscale gateway proxies. CoreDNS remained at the same Deployment generation after an explicit Argo CD refresh, all five ExternalSecrets reported `SecretSynced` with `Ready=True`, External DNS repeatedly reported records up to date, and the Tailscale ProxyGroup remained ready.

Restart counters retain failures from before the repair. An unchanged nonzero counter is not a new crash. This initial observation preceded the Talos upgrade reboot and did not establish that pod routing survived a node restart. The subsequent Cilium VXLAN repair above removes the dependency on leftover Flannel state.
