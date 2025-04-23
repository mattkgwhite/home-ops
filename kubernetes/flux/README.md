# Flux

The configuration within this folder, relates to the delcarative Kubernetes configuration that is used by [FluxCD](https://fluxcd.io/flux/)

## Setup

First you will need the following:

- 1Password
- A Cloudflare Account with a Domain setup.
- A Server with Kubernetes already installed.

### 1Password Credentials

- Create a vault called `homelab` or an existing vault.
- Follow https://developer.1password.com/docs/connect/get-started/#step-1-set-up-a-secrets-automation-workflow 1Password.com tab for generating 1password-credentials.json and save into bootstrap directory.
- Follow https://developer.1password.com/docs/connect/get-started/#step-1-set-up-a-secrets-automation-workflow 1Password CLI tab for generating a 1password connect token and save as 1password-token.secret in bootstrap directory.

### Installing Flux

Firstly create a namespace called `flux-system`, using the following command:

```shell
kubectl create namespace flux-system
```

Next use the following command to install flux into the newly created namespace

```shell
flux install --namespace=flux-system
```

`https://fluxcd.io/flux/cmd/flux_install/`

## Install Cilium

Run the following command from within the Cilium App folder.

```shell
kustomize build --enable-alpha-plugins | k apply -f -
```

## Commands

```shell
kubectl kustomize <path-to-directory>
```

Install Kustomize on Ubuntu:

```shell
curl -LO https://github.com/kubernetes-sigs/kustomize/releases/latest/download/kustomize_v5.6.0_linux_amd64.tar.gz
tar -xvzf kustomize_v5.6.0_linux_amd64.tar.gz
chmod +x kustomize
sudo mv kustomize /usr/local/bin/
```

## Manual Setup Commands

### Cilium

```bash
# Add the Cilium Helm repository and update
helm repo add cilium https://helm.cilium.io/
helm repo update

# Install Cilium
helm upgrade --install cilium cilium/cilium \
--namespace=kube-system --version 1.17.2 \
--values kubernetes/flux/core/kube-system/cilium/values.yml
```

### CoreDNS

```bash
# Add the CoreDNS Helm repository and update
helm repo add coredns https://coredns.github.io/helm
helm repo update

# Install CoreDNS
helm upgrade --install coredns coredns/coredns \
--namespace=kube-system --version 1.39.2 \
--values kubernetes/flux/core/kube-system/coredns/values.yaml
```

#### Testing CoreDNS is installed

```bash
kubectl run -it --rm --restart=Never --image=infoblox/dnstools:latest dnstools
```