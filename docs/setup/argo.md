# Argo

The configuration within this folder, relates to the declarative Kubernetes configuration that is used by [ArgoCD](https://argo-cd.readthedocs.io/en/stable/)

*This repo is subject to change, as it is active development* 

## Setup

First you will need the following:

- 1Password
- A Cloudflare Account with a Domain setup.
- A Server with Kubernetes already installed.

### 1Password Credentials

- Create a vault called `homelab` or an existing vault.
- Follow https://developer.1password.com/docs/connect/get-started/#step-1-set-up-a-secrets-automation-workflow 1Password.com tab for generating 1password-credentials.json and save into bootstrap directory.
- Follow https://developer.1password.com/docs/connect/get-started/#step-1-set-up-a-secrets-automation-workflow 1Password CLI tab for generating a 1password connect token and save as 1password-token.secret in bootstrap directory.

### External DNS & Cloudflare

- In the homelab vault, create a secret called `cf-dns`
- Follow https://developers.cloudflare.com/fundamentals/api/get-started/create-token/ for generating a token and save into key named cloudflare-token

### Networking

Cilium and Hubble

Hubble is a dashboard / visual UI for cilium networking - https://github.com/cilium/hubble?tab=readme-ov-file#what-is-hubble


Cilium [Loadbalancer IP Address Management](https://docs.cilium.io/en/stable/network/lb-ipam/)

Cilium CRD locations (need ip pools & l2 announcement policy from the URL below)

- https://github.com/cilium/cilium/tree/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1
- https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliuml2announcementpolicies.yaml

### Certificates

Cert Manager CRDs (Need ClusterIssuer)
- https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml

### Secrets

```shell
kubectl create secret generic 1passwordconnect --namespace external-secrets --from-literal token=$<token-secret>
```

## Installation

## Requirements

The following installs the required CRDs for services that are on the cluster.

Cilium:

```shell
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumbgppeerconfigs.yaml \
  -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliumendpointslices.yaml \
  -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliumgatewayclassconfigs.yaml \
  -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliuml2announcementpolicies.yaml \
  -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliumpodippools.yaml \
  -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumloadbalancerippools.yaml \
  -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumendpoints.yaml \
  -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumnodes.yaml \
  -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumnetworkpolicies.yaml \
  -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliumdatapathplugins.yaml \
  -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliuml2announcementpolicies.yaml \
  -f 
```

Gateway-Api:

```shell
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml \
  -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/standard/gateway.networking.k8s.io_gateways.yaml \
  -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml \
  -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml \
  -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml \
  -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml
```

Cert-Manager: 

For cert-manager go onto the official release version and copy the link to the cert-manager.crds.yaml file and then apply that file.

```shell
kubectl apply -f <cert-manager.crds.yaml from releases>
```

Envoy-Gateway:

Need to run the following in order to install the relevant missing CRDs from the Envoy-Gateway deployment / install.

```shell
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/experimental/gateway.networking.k8s.io_httproutes.yaml --server-side

below need fixing or investigating as to make sure that the urls are
kubectl apply -f https://raw.githubusercontent.com/envoyproxy/gateway/refs/heads/main/charts/gateway-helm/crds/generated/gateway.envoyproxy.io_envoyproxies.yaml --server-side --force-conflicts
kubectl apply -f https://raw.githubusercontent.com/envoyproxy/gateway/refs/heads/main/charts/gateway-helm/crds/gatewayapi-crds.yaml --server-side --force-conflicts
```

### Base Configuration

```shell
export SETUP_NODEIP=192.168.1.60
# I am using a single node, so the SETUP_CLUSTERTOKEN below is not required.
# export SETUP_CLUSTERTOKEN=randomtokensecret

# CREATE SINGLE NODE
# K3S has a known issue with using systemd and resolv.conf, shown here - https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/#known-issues
# The configuration below sets --resolv-conf to be the systemd reference on debian based systems such as Ubuntu Server, as given in the following GitHub comment - https://github.com/k3s-io/k3s/issues/4087#issuecomment-928882824

curl -fL https://get.k3s.io | INSTALL_K3S_CHANNEL=latest sh -s - server --cluster-init --kube-apiserver-arg default-not-ready-toleration-seconds=10 --kube-apiserver-arg default-unreachable-toleration-seconds=10 --disable=coredns,flannel,metrics-server,servicelb,traefik --flannel-backend none --disable-network-policy --disable-cloud-controller --disable-kube-proxy --resolv-conf /run/systemd/resolve/resolv.conf

# CREATE MASTER NODE
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.32.1+k3s1" INSTALL_K3S_EXEC="--node-ip $SETUP_NODEIP --disable=coredns,flannel,metrics-server,servicelb,traefik --flannel-backend='none' --disable-network-policy --disable-cloud-controller --disable-kube-proxy" K3S_KUBECONFIG_MODE=644 sh K3S_TOKEN=$SETUP_CLUSTERTOKEN -s - 
kubectl taint nodes rk1-01 node-role.kubernetes.io/control-plane:NoSchedule

# INSTALL CILIUM
export cilium_applicationyaml=$(curl -sL "https://raw.githubusercontent.com/mattkgwhite/home-ops/main/kubernetes/argo/manifests/kube-system.yaml" | yq eval-all '. | select(.metadata.name == "cilium" and .kind == "Application")' -)
export cilium_name=$(echo "$cilium_applicationyaml" | yq eval '.metadata.name' -)
export cilium_chart=$(echo "$cilium_applicationyaml" | yq eval '.spec.source.chart' -)
export cilium_repo=$(echo "$cilium_applicationyaml" | yq eval '.spec.source.repoURL' -)
export cilium_namespace=$(echo "$cilium_applicationyaml" | yq eval '.spec.destination.namespace' -)
export cilium_version=$(echo "$cilium_applicationyaml" | yq eval '.spec.source.targetRevision' -)
export cilium_values=$(echo "$cilium_applicationyaml" | yq eval '.spec.source.helm.valuesObject' - | yq eval 'del(.gatewayAPI)' - | yq eval 'del(.ingressController)' -)

echo "$cilium_values" | helm template $cilium_name $cilium_chart --repo $cilium_repo --version $cilium_version --namespace $cilium_namespace --values - | kubectl apply --filename -

# INSTALL COREDNS
export coredns_applicationyaml=$(curl -sL "https://raw.githubusercontent.com/mattkgwhite/home-ops/main/kubernetes/argo/manifests/kube-system.yaml" | yq eval-all '. | select(.metadata.name == "coredns" and .kind == "Application")' -)
export coredns_name=$(echo "$coredns_applicationyaml" | yq eval '.metadata.name' -)
export coredns_chart=$(echo "$coredns_applicationyaml" | yq eval '.spec.source.chart' -)
export coredns_repo=$(echo "$coredns_applicationyaml" | yq eval '.spec.source.repoURL' -)
export coredns_namespace=$(echo "$coredns_applicationyaml" | yq eval '.spec.destination.namespace' -)
export coredns_version=$(echo "$coredns_applicationyaml" | yq eval '.spec.source.targetRevision' -)
export coredns_values=$(echo "$coredns_applicationyaml" | yq eval '.spec.source.helm.valuesObject' -)

echo "$coredns_values" | helm template $coredns_name $coredns_chart --repo $coredns_repo --version $coredns_version --namespace $coredns_namespace --values - | kubectl apply --namespace $coredns_namespace --filename -

# JOIN NODES TO CLUSTER
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.32.1+k3s1" K3S_URL=https://$SETUP_NODEIP:6443 K3S_TOKEN=$SETUP_CLUSTERTOKEN sh -
# LABEL NODES AS WORKERS
kubectl label nodes mynodename kubernetes.io/role=worker
```

### Secrets

```Shell
# 1password-cli is required
## https://developer.1password.com/docs/cli/get-started
# login via `eval $(op signin)`

export domain="$(op read op://homelab/stringreplacesecret/domain)" / Powershell example "$env:DOMAIN = & op read "op://homelab/stringreplacesecret/domain" "
# export cloudflaretunnelid="$(op read op://homelab/stringreplacesecret/cloudflaretunnelid)"
# export onepasswordconnect_json="$(op read op://homelab/1Password/1password-credentials.json | base64)"
export onepasswordconnect_json="$(op read op://homelab/1passwordconnect/1password-credentials.json)"
export externalsecrets_token="$(op read op://homelab/external-secrets/token)"

kubectl create namespace 1passwordconnect
kubectl create secret generic 1passwordconnect --namespace 1passwordconnect --from-literal 1password-credentials.json="$onepasswordconnect_json"

kubectl create namespace external-secrets
kubectl create secret generic 1passwordconnect --namespace external-secrets --from-literal token=$externalsecrets_token

kubectl create namespace argocd
# kubectl create secret generic stringreplacesecret --namespace argocd --from-literal domain=$domain --from-literal cloudflaretunnelid=$cloudflaretunnelid

```

### ArgoCD

Create namespace for ArgoCD and install the default configuration into the ArgoCD namespace

```shell
export argocd_applicationyaml=$(curl -sL "https://raw.githubusercontent.com/mattkgwhite/home-ops/main/kubernetes/argo/manifests/argocd.yaml" | yq eval-all '. | select(.metadata.name == "argocd" and .kind == "Application")' -)
export argocd_name=$(echo "$argocd_applicationyaml" | yq eval '.metadata.name' -)
export argocd_chart=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.chart' -)
export argocd_repo=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.repoURL' -)
export argocd_namespace=$(echo "$argocd_applicationyaml" | yq eval '.spec.destination.namespace' -)
export argocd_version=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.targetRevision' -)
export argocd_values=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.helm.valuesObject' - | yq eval 'del(.configs.cm)' -)
export argocd_config=$(curl -sL "https://raw.githubusercontent.com/mattkgwhite/home-ops/main/kubernetes/argo/manifests/argocd.yaml" | yq eval-all '. | select(.kind == "AppProject" or .kind == "ApplicationSet")' -)

# install
echo "$argocd_values" | helm template $argocd_name $argocd_chart --repo $argocd_repo --version $argocd_version --namespace $argocd_namespace --values - | kubectl apply --namespace $argocd_namespace --filename -

# configure
echo "$argocd_config" | kubectl apply --filename -
```

### Manage Argo CD and application discovery from Git

`kubernetes/argo/bootstrap.yaml` declares the root Application named `manifests`.
It watches only `kubernetes/argo/manifests/argocd.yaml` on `main`, so Argo CD manages
its own Helm Application, the default project, and the `homelab-manifest`
ApplicationSet. The Helm Application named `argocd` manages the Argo CD workloads;
it does not read the Git manifest directly.

Publish the reviewed configuration to `main`, then run this once from the
repository root after the initial Argo CD installation:

```sh
mise x -- kubectl apply --server-side -f kubernetes/argo/bootstrap.yaml
```

The root automatically syncs and self-heals. Automatic pruning is disabled to
match the existing manifest parents. Its definition is the bootstrap entry point;
changes to `bootstrap.yaml` itself require reapplying that file.

The ownership chain is:

```text
manifests -> argocd.yaml -> homelab-manifest ApplicationSet
                       -> argocd Helm Application -> Argo CD workloads
homelab-manifest -> <filename>.manifest -> selected file -> Helm Applications
```

Add new files to the ApplicationSet's explicit `generators.git.files` list and
publish both changes. The root updates the live list automatically, and the
ApplicationSet creates the new parent. Changes to files already on that list
are reconciled by their existing parents. Files outside the list are not enabled
automatically.

Application Git polling is configured in Helm under
`configs.cm.timeout.reconciliation: 300s`, with zero additional jitter. The Git
generator uses `requeueAfterSeconds: 300`. These are five-minute polling intervals,
not a guaranteed deployment deadline: cache expiry, multiple reconciliation
steps, sync errors, and workload readiness can add delay. The chart includes
ConfigMap checksums in controller and repo-server pod templates, so Helm rolls
them when this configuration changes.

Verify activation without exposing credentials:

```sh
mise x -- kubectl get applications manifests argocd -n argocd
mise x -- kubectl get applicationset homelab-manifest -n argocd
mise x -- kubectl get configmap argocd-cm -n argocd -o 'jsonpath={.data.timeout\.reconciliation}{"\n"}{.data.timeout\.reconciliation\.jitter}{"\n"}'
```

The root should report `Synced`, and the ConfigMap should report `300s` and `0s`.
If an application is discovered but remains unhealthy, inspect its sync result,
pod conditions, and events separately. A successful Git refresh cannot correct
missing credentials, image pull failures, or invalid workload configuration.

References: [Argo CD polling](https://argo-cd.readthedocs.io/en/stable/faq/#how-often-does-argo-cd-check-for-changes-to-my-git-or-helm-repository),
[Git generator polling](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/#git-polling-interval),
and [cluster bootstrapping](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/).

### Manage cluster networking from Git

The `homelab-manifest` ApplicationSet in `kubernetes/argo/manifests/argocd.yaml` creates `kube-system.manifest` and `tailscale.manifest`. Each reads one explicitly selected file from `kubernetes/argo/manifests` on `main`, automatically applies changes, and self-heals drift. These parents manage the Cilium, CoreDNS, and Tailscale Application definitions and related existing resources; their Helm Applications manage the generated workloads.

Keep the corrected networking manifests in Git before enabling these parents. See [Talos networking persistence and activation](talos.md#persist-the-fixes-through-argo-cd) for the source files, activation commands, and reboot verification checks.

### Understand the `.manifest` applications and resource ownership

The `.manifest` suffix is an Application name generated by `homelab-manifest`;
it is not a separate file extension. The ApplicationSet's Git generator lists
the enabled YAML files, and its template names each parent with
`{{ trimSuffix ".yaml" .path.filename }}.manifest`. Each parent reads exactly that
file through `source.directory.include`. The file can contain child Helm
Applications as well as resources such as namespaces, ExternalSecrets, and
Ingresses.

For example, `gotify.manifest` reads `gotify.yaml` and manages the `gotify`
Application and related manifest resources. The `gotify` Application manages
the workloads rendered by its Helm chart. The two Applications represent
different levels of management.

| Generated parent | File in `kubernetes/argo/manifests` | Child Applications |
| --- | --- | --- |
| `cert-manager.manifest` | `cert-manager.yaml` | `cert-manager` |
| `crossplane.manifest` | `crossplane.yaml` | `crossplane-system` |
| `external-dns.manifest` | `external-dns.yaml` | `external-dns` |
| `external-secrets.manifest` | `external-secrets.yaml` | `external-secrets` |
| `gotify.manifest` | `gotify.yaml` | `gotify` |
| `hcloud.manifest` | `hcloud.yaml` | `hcloud-csi` |
| `kube-system.manifest` | `kube-system.yaml` | `cilium`, `coredns`, `gatewaycrds`, `metrics-server` |
| `monitoring.manifest` | `monitoring.yaml` | `grafana`, `kube-prometheus-stack`, `loki`, `fluentbit` when enabled |
| `postgres.manifest` | `postgres.yaml` | None; manages the PostgreSQL custom resource and PushSecrets |
| `postgres-operator.manifest` | `postgres-operator.yaml` | `postgres-operator`, `postgres-operator-ui` |
| `reloader.manifest` | `reloader.yaml` | `reloader` |
| `rustfs.manifest` | `rustfs.yaml` | `rustfs` |
| `storage.manifest` | `storage.yaml` | `csi-smb` |
| `tailscale.manifest` | `tailscale.yaml` | `tailscale` |

The root `manifests` Application comes from `bootstrap.yaml`, not the
ApplicationSet. It reads `argocd.yaml` and manages the ApplicationSet and the
`argocd` Helm Application. Applications outside this table may be standalone;
inspect their `metadata.ownerReferences` and source before assuming they were
generated by this ApplicationSet.

A 2026-11-05 audit of the 38 live Applications and their reported resources found one
shared-resource identity: `Namespace/crossplane-system`, declared in both
`crossplane.yaml` and `crossplane-providers.yaml`. Because both Applications had
self-healing enabled, either could replace the other's Argo tracking annotation
and return it to `OutOfSync`.

Keep this Namespace in `crossplane-providers.yaml`, which is included by the
`crossplane-system` Application's `crossplane-*.yaml` source. The parent
`crossplane.yaml` declares the child Application and the activation policy only.
Removing the duplicate from the parent is the safe transition for the existing
configuration: `crossplane.manifest` has automatic pruning disabled, while the
child continues to declare the Namespace. The change does not require deleting
the Namespace, providers, or workloads. Sync the parent without selecting manual
pruning; leave the child Namespace declaration in place.

After publishing and syncing, confirm the shared-resource warning clears:

```sh
mise x -- kubectl get applications crossplane.manifest crossplane-system -n argocd
mise x -- kubectl get application crossplane.manifest -n argocd -o 'jsonpath={.status.conditions}{"\n"}'
mise x -- kubectl get namespace crossplane-system -o 'jsonpath={.metadata.annotations.argocd\.argoproj\.io/tracking-id}{"\n"}'
```

The Namespace tracking annotation should identify `crossplane-system`, and the
parent should no longer report a `SharedResourceWarning` for it. The audit did
not identify another shared resource; the `gatewaycrds` plugin error and
`kestra` chart-version error are separate manifest-generation failures.

To keep monitoring temporarily disabled, remove or comment its Git-generator
entry and publish that change. Removing its pods or child Applications alone
leaves its GitOps definition enabled. With `preserveResourcesOnDeletion: true`,
removing the generator entry preserves any remaining resources; it does not
uninstall the workload or delete its volumes.

### CRDs

- [Cilium](https://github.com/cilium/cilium/tree/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1)
```shell
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumbgpadvertisements.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumbgpclusterconfigs.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumbgpnodeconfigoverrides.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumbgpnodeconfigs.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumbgppeerconfigs.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumcidrgroups.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumclusterwideenvoyconfigs.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumclusterwidenetworkpolicies.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumegressgatewaypolicies.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumendpoints.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumenvoyconfigs.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumidentities.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumloadbalancerippools.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumlocalredirectpolicies.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumnetworkpolicies.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumnodeconfigs.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2/ciliumnodes.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/v1.19.3/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliuml2announcementpolicies.yaml \
-f https://raw.githubusercontent.com/cilium/cilium/v1.19.3/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliumpodippools.yaml
```

- [Gateway](https://github.com/kubernetes-sigs/gateway-api/tree/main/config/crd/standard)
```shell 
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/standard/gateway.networking.k8s.io_backendtlspolicies.yaml \
-f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml \
-f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/standard/gateway.networking.k8s.io_gateways.yaml \
-f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml \
-f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml \
-f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/standard/gateway.networking.k8s.io_listenersets.yaml \
-f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml \
# -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/standard/gateway.networking.k8s.io_tlsroutes.yaml \ # this is the v1 version of the CRD, and because the current version needs v1alpha2 it needs the following version installed instead.
-f kubectl replace -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml \
-f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/refs/heads/main/config/crd/standard/gateway.networking.k8s.io_vap_safeupgrades.yaml
```

- [External Secret](https://github.com/external-secrets/external-secrets/tree/main/config/crds/bases)
```shell
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/external-secrets.io_clusterexternalsecrets.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/external-secrets.io_clusterpushsecrets.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/external-secrets.io_clustersecretstores.yaml --server-side \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/external-secrets.io_externalsecrets.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/external-secrets.io_pushsecrets.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/external-secrets.io_secretstores.yaml --server-side\
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_acraccesstokens.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_cloudsmithaccesstokens.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_clustergenerators.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_ecrauthorizationtokens.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_fakes.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_gcraccesstokens.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_generatorstates.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_githubaccesstokens.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_grafanas.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_mfas.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_passwords.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_quayaccesstokens.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_sshkeys.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_stssessiontokens.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_uuids.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_vaultdynamicsecrets.yaml \
  -f https://raw.githubusercontent.com/external-secrets/external-secrets/refs/heads/main/config/crds/bases/generators.external-secrets.io_webhooks.yaml
``` 

- Cert-Manager - These are contained within the `release` on Github, for example [v1.17.1](https://github.com/cert-manager/cert-manager/releases/tag/v1.17.1) has a file within assets called `cert-manager.crds.yaml`. This can just be applied using `k apply -f <copy-link-address>`

```shell
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.20.2/cert-manager.crds.yaml

-[External-DNS](https://github.com/kubernetes-sigs/external-dns/blob/master/config/crd/standard/dnsendpoints.externaldns.k8s.io.yaml)

```shell
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/external-dns/refs/heads/master/config/crd/standard/dnsendpoints.externaldns.k8s.io.yaml
```

- [ArgoCD]()

```shell
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/refs/heads/master/manifests/crds/application-crd.yaml \
-f https://raw.githubusercontent.com/argoproj/argo-cd/refs/heads/master/manifests/crds/applicationset-crd.yaml \
-f https://raw.githubusercontent.com/argoproj/argo-cd/refs/heads/master/manifests/crds/appproject-crd.yaml
```

### Utils

- CSI Driver - `sudo apt install cifs-utils`
