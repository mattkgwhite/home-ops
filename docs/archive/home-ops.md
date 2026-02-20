# HOME-OPS

This repository contains the Kubernetes configuration files managed by GitOps, specifically [ArgoCD](https://argo-cd.readthedocs.io/en/stable/) and is a work is progress / under development.

Using a combination of a variety of resources such as [Vault](https://www.vaultproject.io/), [SOPS](https://github.com/mozilla/sops), [Age](https://github.com/FiloSottile/age)

### Requirements

- ksops: https://github.com/viaduct-ai/kustomize-sops
  - Required to build the secrets defined as part of the configuration.
- sops: https://github.com/mozilla/sops
  - encrypt secrets stored in `secret.sops.yaml` files within this repository.

### TODO

- [X] Folder Structure Setup
  - [ ] Addition Configuration, On-Going
- [X] Secret Management - SOPS, Age & KSOPS
- [X] Metallb - Load Balancer
- [X] SSL Certificates - Cert Manager
- [X] DNS Records - External DNS
- [X] Ingress - Ingress-Nginx
- [X] ArgoCD
- [X] Cluster Bootstrapping - handover control after bootstrapping cluster to ArgoCD.
- [X] Storage
  - [X] HCloud Volumes
- [ ] Monitoring & Alerting
  - [ ] kube-prometheus-stack
  - [ ] loki
- [ ] Security
  - [X] Authentication / Access Control
    - [X] Authentik
- [ ] Database
  - [ ] PGNative
- [ ] CI / CD
  - [ ] Jenkins
- [ ] Backups
  - [ ] Scheduled / Automated
  - [ ] External Backups

## 📂 Repository structure

## Setup - Single Cluster

After creating the Node / Host, the following command needs to be run against the Node / Host. This specific command will downloading the latest K3s server install, and install against the Node / Host...With the Traefik and ServiceLB disabled.

```shell
curl -fL https://get.k3s.io | INSTALL_K3S_CHANNEL=latest sh -s - server --cluster-init --kube-apiserver-arg default-not-ready-toleration-seconds=10 --kube-apiserver-arg default-unreachable-toleration-seconds=10 --disable=traefik,servicelb
```

### Configuration Updates

1. 00-secrets - update the secrets.sops.yaml file with relevant AWS Credentials.
2. 01-metallb - update Public IP Address reference in ipaddress.yaml file.
3. 02-cert-manager - update clusterissuer.yaml file, specifically email reference, access-key reference and dnsNames.
4. 03-external-dns - update values.yaml file, specifically domainFilters
5. 04-ingress-nginx - update services.yaml file, specifically IPV4 address with the IPV4 address entered into `01-metallb > ipaddress.yaml` and the domain reference for *external-dns.alpha.kubernetes.io/hostname*
6. 05-argocd - update domain references
7. 06-bootstrapping-argoprojects - update names and github repository references.

### Prerequisites for Cluster

**CSI Driver** - Access to remote storage via a CIFs Share. To install use one of the following depending on Host Node OS:

```
Ubuntu: `sudo apt-get install -y cifs-utils`
CentOS: `yum -y install cifs-utils`
```

### 💾 Storage

Remote Storage: 
This functionality requires the CSI-Driver to be install from the `Prerequisites for Cluster:` section. Once install will provide the ability of the cluster to reference remote storage options such as [Hetzner's Storage Boxes](https://www.hetzner.com/storage/storage-box), which are scaleable options for remote storage.

- Hetzner Storage Box
- Hetzner 'hcloud-csi-driver' - virtual disks against the VPS itself.

### Databaase

Databases that are waiting to be configured and deployed to the cluster:

- Postgresql
- pg-native

### Monitoring

Monitoring services that are waiting to be configured and deployed to the cluster:

- Grafana
- Loki
- Prometheus

### Authentication

Authentication services that are waiting to be configured and deployed to the cluster:

- Authelia
- 0Auth
- Keycloak

### CI/CD

CI/CD services that are waiting to be configured and deployed to the cluster:

- Jenkins
- Tekton