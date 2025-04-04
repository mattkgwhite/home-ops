# Argo

The configuration within this folder, relates to the declarative Kubernetes configuration that is used by [ArgoCD](https://argo-cd.readthedocs.io/en/stable/)

*This repo is subject to change, as it is active development* 

## Setup

First you will need the following:

- 1Password
- An AWS Account
- An IAM User with *Programmatic Access* configuration, and the Access Key and Secret Access Key from that user.
- A Domain that has been setup with Route53
- A Virtual Machine with a Public IPv4 Address

### 1Password Credentials

- Create a vault called `default`
- Follow https://developer.1password.com/docs/connect/get-started/#step-1-set-up-a-secrets-automation-workflow 1Password.com tab for generating 1password-credentials.json and save into bootstrap directory.
- Follow https://developer.1password.com/docs/connect/get-started/#step-1-set-up-a-secrets-automation-workflow 1Password CLI tab for generating a 1password connect token and save as 1password-token.secret in bootstrap directory.

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

## Base Configuration & Requirements

```shell


export SETUP_NODEIP=192.168.1.60
# I am using a single node, so the SETUP_CLUSTERTOKEN below is not required.
# export SETUP_CLUSTERTOKEN=randomtokensecret

# CREATE MASTER NODE
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.32.1+k3s1" INSTALL_K3S_EXEC="--node-ip $SETUP_NODEIP --disable=coredns,flannel,local-storage,metrics-server,servicelb,traefik --flannel-backend='none' --disable-network-policy --disable-cloud-controller --disable-kube-proxy" K3S_TOKEN=$SETUP_CLUSTERTOKEN K3S_KUBECONFIG_MODE=644 sh -s -
kubectl taint nodes rk1-01 node-role.kubernetes.io/control-plane:NoSchedule


# INSTALL CILIUM
export cilium_applicationyaml=$(curl -sL "https://raw.githubusercontent.com/mattkgwhite/home-ops/main/kubernetes/argo/manifests/cilium.yaml" | yq eval-all '. | select(.metadata.name == "cilium" and .kind == "Application")' -)
export cilium_name=$(echo "$cilium_applicationyaml" | yq eval '.metadata.name' -)
export cilium_chart=$(echo "$cilium_applicationyaml" | yq eval '.spec.source.chart' -)
export cilium_repo=$(echo "$cilium_applicationyaml" | yq eval '.spec.source.repoURL' -)
export cilium_namespace=$(echo "$cilium_applicationyaml" | yq eval '.spec.destination.namespace' -)
export cilium_version=$(echo "$cilium_applicationyaml" | yq eval '.spec.source.targetRevision' -)
export cilium_values=$(echo "$cilium_applicationyaml" | yq eval '.spec.source.helm.valuesObject' - | yq eval 'del(.gatewayAPI)' - | yq eval 'del(.ingressController)' -)

echo "$cilium_values" | helm template $cilium_name $cilium_chart --repo $cilium_repo --version $cilium_version --namespace $cilium_namespace --values - | kubectl apply --filename -

# INSTALL COREDNS
export coredns_applicationyaml=$(curl -sL "https://raw.githubusercontent.com/mattkgwhite/home-ops/main/kubernetes/argo/manifests/cilium.yaml" | yq eval-all '. | select(.metadata.name == "coredns" and .kind == "Application")' -)
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


### ArgoCD

Create namespace for ArgoCD and install the default configuration into the ArgoCD namespace

```shell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Access The Argo CD API Server, by updating the service to *LoadBalancer* using for the following command

`kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'`



```shell
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: pool
spec:
  blocks:
    - start: "192.168.2.10"
      stop: "192.168.2.20"
```

### CRDs

Cilium CRDs can be found here -https://github.com/cilium/cilium/tree/main/pkg/k8s/apis/cilium.io/client/crds/v2alpha1

