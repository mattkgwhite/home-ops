PLAN.md --- home-ops Repository Restructure

Objective

Restructure the existing home-ops repository into a singleInfrastructure Engineering Handbook that combines:

Infrastructure as Code (IaC)

GitOps

Architecture documentation

Operational runbooks

Reference designs

Automation

Configuration

Do not modify live Kubernetes manifests or infrastructure behaviourunless explicitly required by this plan.

Primary Goals

Preserve all existing infrastructure code.

Introduce a documentation-first structure.

Keep documentation alongside the code it describes.

Make the repository suitable for Obsidian and GitHub.

Keep CURRENT-DESIGN.md as the concise source of truth.

Target Structure

home-ops/
├── README.md
├── CURRENT-DESIGN.md
├── CHANGELOG.md
├── ROADMAP.md
├── docs/
│   ├── architecture/
│   ├── platforms/
│   │   ├── mini-rack/
│   │   ├── kubernetes/
│   │   ├── networking/
│   │   ├── storage/
│   │   ├── hetzner/
│   │   └── cloudflare/
│   ├── operations/
│   │   ├── runbooks/
│   │   ├── maintenance/
│   │   ├── upgrades/
│   │   └── disaster-recovery/
│   ├── reference/
│   │   ├── hardware/
│   │   ├── vendors/
│   │   └── reference-builds/
│   └── decisions/
├── adr/
├── kubernetes/
├── ansible/
├── docker/
├── terraform/
├── opentofu/
├── configs/
├── automation/
├── scripts/
├── diagrams/
├── images/
└── inventory/

Rules

Never delete existing files without confirmation.

Move files rather than recreating them where practical.

Preserve Git history where possible.

Prefer incremental pull requests/commits.

Add README.md files to major directories.

Record assumptions with TODO markers.

Documentation Standards

Each platform directory should contain:

README.md

Architecture overview

Configuration overview

Deployment notes

Upgrade procedure

Troubleshooting

Links to live configuration

CURRENT-DESIGN.md

Maintain as a one-page summary including:

Current version

Current status

Physical platforms

Logical platforms

Core services

Open decisions

Next milestone

Avoid detailed explanations.

Architecture Decision Records

Create ADRs for major decisions, including:

External NAS

16U rack

UniFi networking

K3s

Argo CD

Backup strategy

Each ADR should include Context, Decision, Alternatives, Consequences.

Existing Infrastructure

Document, but do not alter unless instructed:

Kubernetes manifests

Argo CD Applications

Helm values

Ansible playbooks

Docker Compose

Hetzner VPS configuration

Cloudflare configuration

Deliverables

Restructured repository.

README files.

Documentation index.

ADR framework.

Updated CURRENT-DESIGN.md.

Migration summary listing moved files and outstanding TODOs.