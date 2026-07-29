# Disaster Recovery

## Recovery order

1. Restore operator credentials and provider access.
2. Restore compute, network paths, DNS, and the Kubernetes control plane.
3. Bootstrap Argo CD and external-secret access.
4. Reconcile stateless services from Git.
5. Restore persistent data from verified backups.
6. Validate ingress, DNS, identity, applications, and monitoring.

Git reconstructs desired state but is not a backup of persistent data.

TODO: Define RPO/RTO, owners, schedules, encryption, retention, off-site copies,
and last-tested restores.
