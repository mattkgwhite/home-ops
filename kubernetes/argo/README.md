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

### Secrets
```
# 1password-cli is required
## https://developer.1password.com/docs/cli/get-started
# login via `eval $(op signin)`

export domain="$(op read op://homelab/stringreplacesecret/domain)"
export cloudflaretunnelid="$(op read op://homelab/stringreplacesecret/cloudflaretunnelid)"
export onepasswordconnect_json="$(op read op://homelab/1Password/1password-credentials.json | base64)"
export externalsecrets_token="$(op read op://homelab/1Password/token)"

kubectl create namespace argocd
kubectl create secret generic stringreplacesecret --namespace argocd --from-literal domain=$domain --from-literal cloudflaretunnelid=$cloudflaretunnelid

kubectl create namespace 1passwordconnect
kubectl create secret generic 1passwordconnect --namespace 1passwordconnect --from-literal 1password-credentials.json="$onepasswordconnect_json"

kubectl create namespace external-secrets
kubectl create secret generic 1passwordconnect --namespace external-secrets --from-literal token=$externalsecrets_token
```

### Setup

```shell
# REQUIRED PACKAGES
# yq
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq
# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### ArgoCD

```shell
export argocd_applicationyaml=$(curl -sL "https://raw.githubusercontent.com/mattkgwhite/home-ops/refs/heads/main/kubernetes/argo/manifests/argocd.yaml" | yq eval-all '. | select(.metadata.name == "argocd" and .kind == "Application")' -)
export argocd_name=$(echo "$argocd_applicationyaml" | yq eval '.metadata.name' -)
export argocd_chart=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.chart' -)
export argocd_repo=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.repoURL' -)
export argocd_namespace=$(echo "$argocd_applicationyaml" | yq eval '.spec.destination.namespace' -)
export argocd_version=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.targetRevision' -)
export argocd_values=$(echo "$argocd_applicationyaml" | yq eval '.spec.source.helm.valuesObject' - | yq eval 'del(.configs.cm)' -)
export argocd_config=$(curl -sL "https://raw.githubusercontent.com/mattkgwhite/home-ops/refs/heads/main/kubernetes/argo/manifests/argocd.yaml" | yq eval-all '. | select(.kind == "AppProject" or .kind == "ApplicationSet")' -)

# install
echo "$argocd_values" | helm template $argocd_name $argocd_chart --repo $argocd_repo --version $argocd_version --namespace $argocd_namespace --values - | kubectl apply --namespace $argocd_namespace --filename -

# configure
echo "$argocd_config" | kubectl apply --filename -
```
