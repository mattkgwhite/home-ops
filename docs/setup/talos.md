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

### Current inter-node transport: UDP 4789

On 2026-10-17, both nodes still had a `flannel.1` VXLAN interface using VNI `1`, UDP destination port `4789`, and the public `enp1s0` interface. Their remote pod-subnet routes used that interface even though Cilium was configured for native routing. This is the observed transitional configuration, not a completed migration to Cilium-managed routing.

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

Keep UDP `4789` allowed while these routes remain in use. Cilium's default VXLAN port is `8472`, but opening that port does not replace the observed `4789` requirement. A planned migration must establish and verify the replacement routing before removing the old interface or firewall allowance; node rebuilds must not depend on leftover Flannel state.

References: [Flannel VXLAN backend](https://github.com/flannel-io/flannel/blob/master/Documentation/backends.md), [Cilium routing modes and default tunnel ports](https://docs.cilium.io/en/stable/network/concepts/routing/), [Hetzner firewall behavior](https://docs.hetzner.com/cloud/firewalls/faq/).

### Resolver files and firewalls

Keep CoreDNS's explicit upstreams (`forward . 8.8.8.8 8.8.4.4`). `/run/systemd/resolve/resolv.conf` was a workaround for the former Ubuntu/K3s setup and must not be restored on Talos. Talos has `/etc/resolv.conf`, but its host loopback resolver cannot be used by mounting that file into an ordinary pod.

Sidero documents a separate incompatibility between Talos `machine.features.hostDNS.forwardKubeDNSToHost: true` and Cilium `bpf.masquerade: true`. Both were enabled when checked. Disabling forwarding is a documented compatibility workaround, but it does not repair an empty DNS Service or establish that pod-to-API routing works. See [Talos Cilium known issues](https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium).

Hetzner Cloud Firewalls do not filter private Cloud Network traffic. Public inter-node traffic is subject to the firewall; the required rules depend on the actual routing or encapsulation used. Allowing inbound port 53 from pod or Service CIDRs does not fix a Service with no endpoints. If custom outbound rules exist, allow TCP and UDP port 53 to the configured external resolvers. See [Hetzner firewall FAQ](https://docs.hetzner.com/cloud/firewalls/faq/).

DNS Service selection and inter-node transport were separate faults. After restoring both, verify that worker pods can reach the API without control-plane placement workarounds before treating the networking migration as complete.

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

### Argo CD dashboard over Tailscale

The dashboard is available at `https://argo.<tailnet>.ts.net/` while connected to the tailnet. Its active configuration is the `argocd-tailscale` Ingress in `kubernetes/argo/manifests/gateway.yaml`, with `ingressClassName: tailscale`, hostname `argo`, and backend `argocd-server:80` in the `argocd` namespace. Argo CD has `server.insecure: true`; the Tailscale proxy terminates HTTPS and forwards HTTP to the backend. This Ingress provisions a standalone Tailscale proxy because it has no `tailscale.com/proxy-group` annotation; it does not use the existing `tailscale-gateway` ProxyGroup.

During investigation on 2026-10-17, the Ingress existed in the repository but was absent from the cluster. Consequently, the operator had no Argo endpoint to register or present for device approval. The `homelab-manifest` ApplicationSet reported:

```text
ApplicationSet homelab-manifest contains applications with duplicate name: manifests.manifest
```

Its template in `kubernetes/argo/manifests/argocd.yaml` uses `{{.path.basename}}.manifest`. Every matched file is in the same `manifests` directory, so the generated names collide. The source path also points every generated Application at that entire directory. Changing names alone would leave multiple Applications managing the same resources. The ApplicationSet deployment design remains unresolved; applying the Ingress directly restored access, but did not establish GitOps deployment or self-healing for it.

To restore only the existing tailnet Ingress, run from the repository root:

```zsh
mise x -- yq 'select(.kind == "Ingress" and .metadata.name == "argocd-tailscale")' kubernetes/argo/manifests/gateway.yaml | mise x -- kubectl apply -f -
mise x -- kubectl get ingress argocd-tailscale -n argocd -o 'jsonpath={.status.loadBalancer.ingress[0].hostname}{"\n"}'
mise x -- kubectl get pods -n tailscale
```

The hostname is populated after the operator provisions the proxy. The repair created a proxy pod named `ts-argocd-tailscale-<suffix>-0`, which became `1/1 Running` with no restarts. Tailscale reported the device online with no health warnings, and an HTTPS request from the connected client returned HTTP `200` with successful certificate verification. No device approval was blocking access at verification time.

Verify access from a client connected to the tailnet:

```zsh
curl --connect-timeout 10 --max-time 20 -sS -o /dev/null -w 'HTTP %{http_code}\nTLS verification %{ssl_verify_result}\n' https://argo.<tailnet>.ts.net/
```

Expect `HTTP 200` and `TLS verification 0`. The public Argo HTTPRoute is commented out, and the `argocd-public` DNSEndpoint still references an obsolete public address. That record is separate from the tailnet endpoint. Extract only the Ingress when performing this repair: applying all of `gateway.yaml` would also create the obsolete public gateway configuration.

### Verified recovery

After applying the Cilium/CoreDNS Application corrections and the Tailscale namespace exception on 2026-10-17, a 30-minute observation recorded no restart-count increases and no replacements of existing pods. All containers were ready at the observation checks; the only new pods were the two Tailscale gateway proxies. CoreDNS remained at the same Deployment generation after an explicit Argo CD refresh, all five ExternalSecrets reported `SecretSynced` with `Ready=True`, External DNS repeatedly reported records up to date, and the Tailscale ProxyGroup remained ready.

Restart counters retain failures from before the repair. An unchanged nonzero counter is not a new crash. This observation establishes recovery during the measured window, not a guarantee against future failures or the unfinished Flannel-to-Cilium migration.
