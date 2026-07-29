# Home Operations Infrastructure Engineering Handbook

This repository is the source-controlled handbook and implementation for the
home-ops environment. It keeps architecture, operational knowledge, automation,
and GitOps configuration together.

> [!CAUTION]
> Files below `kubernetes/`, `ansible/`, `nix/`, and `scripts/` can affect real
> infrastructure. Review changes and use check or dry-run modes before applying.

## Start here

- [Current design](CURRENT-DESIGN.md) — concise source of truth
- [Documentation index](docs/README.md) — handbook navigation
- [Roadmap](ROADMAP.md) — planned work and open items
- [Architecture decisions](adr/README.md) — why major choices were made
- [Operations](docs/operations/README.md) — runbooks and lifecycle guidance
- [Migration summary](docs/MIGRATION-SUMMARY.md) — moved files and TODOs
- [Changelog](CHANGELOG.md) — notable repository changes

## Repository map

| Path | Purpose |
| --- | --- |
| `docs/` | Architecture, platforms, operations, and reference material |
| `adr/` | Authoritative Architecture Decision Records |
| `kubernetes/` | Kubernetes and GitOps configuration |
| `ansible/` | Host configuration and maintenance automation |
| `nix/` | NixOS experiments and configuration |
| `docker/` | Docker and Compose assets |
| `terraform/`, `opentofu/` | Infrastructure-as-code projects |
| `configs/` | Shared, non-secret configuration |
| `automation/`, `scripts/` | Automation entry points and shell tooling |
| `diagrams/`, `images/` | Source diagrams and shared images |
| `inventory/` | Cross-platform inventory documentation |
| `templates/` | Reusable deployment templates |

## Working with the handbook

Use relative Markdown links for GitHub and Obsidian. Keep detailed instructions
with the relevant platform and keep `CURRENT-DESIGN.md` to one page. Record
major decisions as ADRs. Never commit credentials, decrypted secrets,
kubeconfigs, or private keys.

Before changing live configuration, read the platform guide and ADRs, update
documentation when intent changes, validate with check or dry-run mode, and
submit a focused change.

Empty top-level areas are intentional capability placeholders. Licensing is in
[LICENSE](LICENSE).
