# Home Operations

A comprehensive set of tools and configuration for automating a variety of tasks across multiple environments.

### Directory Helper

```sh
📁  .
├── 📁 .github # Github related files
├── 📁 ansible # Ansible configuration
├── 📁 kubernetes # Kubernetes configuration
│   ├── 📁 argo # ArgoCD kubernetes node configuration
│   └── 📁 flux # FluxCD kubernetes node configuration
├── 📁 scripts # Scrits
├── 📁 taskfiles # Task Scripts. *Work In Progress*
└── 📁 README.md # This file
```

## Cloud Dependencies

| Service                                                 | Use                                                            | Cost           |
|---------------------------------------------------------|----------------------------------------------------------------|----------------|
| [1Password](https://1password.com/)                     | Secrets with [External Secrets](https://external-secrets.io/)  |  ~$36/yr  |
| [Cloudflare](https://www.cloudflare.com/)               | Pages and DNS                                |  Free  |
| [Route53 - Amazon Web Services](https://aws.amazon.com/route53) | Domains used for Service Hosting                                | $9/yr x 2 Domains    |
| [GitHub](https://github.com/)                           | Hosting this repository and continuous integration/deployments | Free           |
| [Let's Encrypt](https://letsencrypt.org/)               | Issuing SSL Certificates with Cert Manager                     | Free           |
| [M365](https://www.microsoft365.com/)                           | Email Hosting, Office Productivity                                                  |  ~8$/mo  |
| [Hetzner Storage-Box](https://www.hetzner.com/storage/storage-box/)                           | Backups, SMB Storage                                  |  ~4$/mo for 1TB |
|                                                         |                                                                | Total: ~$12/mo |

### Hardware

| Hosted | Provider | Specs | Pricing |
| --- | --- | -- | -- |
| Proxmox | Hetzner | Ryzen 1700x, 64GB RAM, 1 x 1TB NVMe, 3 x 512 SSDs, Unlimited Bandwidth to Public Internet (1GBs) | 80 Euro/mo |
| VPS | Hetzner | 4c, 8GB, 40GB SSD, 20TB Bandwidth to Public Internet | 15 Euro/mo |
| Storage | Hetzner | SMB / Hosted Storage | 4 Euro/mo |
|    |     |     | Total: ~99 Euro/mo   |

## Kubernetes

Currently there is only one available configuration for Kubernetes and GitOps which is [ArgoCD](https://argoproj.github.io/cd/). The documentation for this can be found in [Docs -> Setup -> Argo](docs/setup/argo.md)

There will eventually be a configuration for FluxCD added for a Flux based deployment. *However until further notice this currently on hold, while the Argo configuration completed and documented. These configuration are also subject to change.*

Please refer to the documentation previously linked to find what is currently deployed in the Kubernetes. There is an active [ToDo List](docs/todo.md) which will remain as up to date as possible with current pending tasks / deployments and which deployment they are linked to.

There will also be a template / basic configuration for both ArgoCD and FluxCD, to test applications. *For FluxCD this is planned for a later time.*

Basic functionality, includes SSL (Cert-Manager), DNS (External DNS), Ingress (Gateway), Monitoring (Kube-Prometheus-Stack - Grafana, Loki, PrometheusDB), Secret Management (External Secrets & 1Password)

### Kubernetes - Template Clusters

Argo's template cluster can currently be found under [templates -> argo](templates/argo/)

## Docs

- [ToDo](docs/todo.md)
- [Argo Setup](docs/setup/argo.md)
