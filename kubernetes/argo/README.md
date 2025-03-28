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

kubectl create secret generic 1passwordconnect --namespace external-secrets --from-literal token=$<token-secret>