# Migration Summary

## Scope

The August 2026 restructure turns the repository into an Infrastructure
Engineering Handbook without changing infrastructure behavior.

## Moved and preserved files

| Previous path | New path | Reason |
| --- | --- | --- |
| `README.md` | `docs/archive/README-pre-handbook.md` | Preserve the previous entry point before replacing it |
| `docs/todo.md` | `docs/archive/todo-pre-handbook.md` | Preserve the original list; curated work is now in `ROADMAP.md` |
| `docs/setup/argo.md` | `docs/platforms/kubernetes/argo-cd-deployment.md` | Place deployment guidance with Kubernetes |
| `docs/setup/automation.md` | `docs/platforms/kubernetes/crossplane.md` | Place Crossplane notes with Kubernetes |

Historical notes remain under `docs/archive/`; code-adjacent VPS and Flux docs
remain beside their configuration.

## Preservation statement

No Kubernetes YAML, Helm values, Ansible playbook, inventory, Nix expression,
template, or executable script was modified. No existing content was deleted.

## Outstanding TODOs

- Verify the current runtime against `CURRENT-DESIGN.md`.
- Confirm the 16U rack and external NAS status and specifications.
- Create sanitised hardware, host, network, and storage inventory.
- Define and test backup retention, restore procedures, RPO, and RTO.
- Decide the supported status of Flux, Talos, Terraform, and OpenTofu.
- Add architecture and rack diagrams.
