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
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliumbgppeeringpolicies.yaml \
  -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliumendpointslices.yaml \
  -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliumgatewayclassconfigs.yaml \
  -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliuml2announcementpolicies.yaml \
  -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1/ciliumpodippools.yaml
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

export domain="$(op read op://homelab/stringreplacesecret/domain)"
# export cloudflaretunnelid="$(op read op://homelab/stringreplacesecret/cloudflaretunnelid)"
export onepasswordconnect_json="$(op read op://homelab/1Password/1password-credentials.json | base64)"
export externalsecrets_token="$(op read op://homelab/1Password/token)"

kubectl create namespace argocd
# kubectl create secret generic stringreplacesecret --namespace argocd --from-literal domain=$domain --from-literal cloudflaretunnelid=$cloudflaretunnelid

kubectl create namespace 1passwordconnect
kubectl create secret generic 1passwordconnect --namespace 1passwordconnect --from-literal 1password-credentials.json="$onepasswordconnect_json"

kubectl create namespace external-secrets
kubectl create secret generic 1passwordconnect --namespace external-secrets --from-literal token=$externalsecrets_token
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

### CRDs

- [Cilium](https://github.com/cilium/cilium/tree/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1)

- [Gateway](https://github.com/kubernetes-sigs/gateway-api/tree/main/config/crd/standard)

- [External Secret](https://github.com/external-secrets/external-secrets/tree/main/config/crds/bases)

- Cert-Manager - These are contained within the `release` on Github, for example [v1.17.1](https://github.com/cert-manager/cert-manager/releases/tag/v1.17.1) has a file within assets called `cert-manager.crds.yaml`. This can just be applied using `k apply -f <copy-link-address>`

### Utils

- CSI Driver - `sudo apt install cifs-utils`