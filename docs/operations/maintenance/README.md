# Maintenance

Host maintenance playbooks are in
[`ansible/tasks/maintenance/`](../../../ansible/tasks/maintenance/).

Before maintenance, confirm backups, impact, access, and rollback. Use check
mode where supported. Afterward validate host reachability, node and GitOps
health, ingress, DNS, and storage.

TODO: Define a maintenance cadence and tested validation checklist.
