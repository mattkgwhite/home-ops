# Roadmap

This records intended work, not deployed state. See
[CURRENT-DESIGN.md](CURRENT-DESIGN.md) for the current baseline.

## Next milestone: validate and make recoverable

- [ ] Validate the service list against the running cluster.
- [ ] Complete non-secret host, cluster, and storage inventory.
- [ ] Define recovery objectives, retention, and off-site backup ownership.
- [ ] Test and record restore procedures.
- [ ] Confirm the 16U rack and external NAS designs before procurement.

## Platform work

- [x] Argo CD, External Secrets, cert-manager, ExternalDNS, Gateway API, and SMB
- [ ] Monitoring, alerting, Authentik, and a database platform
- [ ] Argo Workflows, Events, Rollouts, and Image Updater
- [ ] Scheduled local and off-site backups
- [ ] Decide whether Flux and Talos become supported paths

## Infrastructure as code and automation

- [ ] Establish a Terraform or OpenTofu project and state policy.
- [ ] Document Crossplane ownership and reconciliation boundaries.
- [ ] Add validation and linting for Ansible and Kubernetes content.
- [ ] Document Taskfile and script entry points.

## Documentation

- [x] Establish handbook structure, indexes, and initial ADRs.
- [ ] Replace every TODO assumption with verified inventory evidence.
- [ ] Add sanitised architecture and network diagrams.
- [ ] Add tested maintenance, upgrade, and recovery procedures.
