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

These are the configurations for kuberentes specifically for GitOps applications [ArgoCD](https://argoproj.github.io/cd/) and [FluxCD](https://fluxcd.io/). *These configurations are a work in progress and are subject to change.*

The configurations contain basic functionality of kubernetes that are specific to both ArgoCD and FluxCD, to test applications or for permanent configuration and deployment.

Basic functionality, includes SSL (Cert-Manager), DNS (External DNS), Ingress (Gateway / Ingress-Nginx / Kong), Monitoring (Kube-Prometheus-Stack - Grafana, Loki, PrometheusDB), Secret Management (External Secrets & 1Password)

## Docs

- [ToDo](docs/setup/todo.md)
- [Argo Setup](docs/setup/argo.md)
