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

- Create a vault called `Homelab`
- Follow https://developer.1password.com/docs/connect/get-started/#step-1-set-up-a-secrets-automation-workflow 1Password.com tab for generating 1password-credentials.json and save into bootstrap directory.
- Follow https://developer.1password.com/docs/connect/get-started/#step-1-set-up-a-secrets-automation-workflow 1Password CLI tab for generating a 1password connect token and save as 1password-token.secret in bootstrap directory.

### Networking

Cilium and Hubble

Hubble is a dashboard / visual UI for cilium networking - https://github.com/cilium/hubble?tab=readme-ov-file#what-is-hubble


Cilium [Loadbalancer IP Address Management](https://docs.cilium.io/en/stable/network/lb-ipam/)