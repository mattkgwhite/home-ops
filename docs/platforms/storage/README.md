# Storage Platform

## Architecture overview

The repository configures the SMB CSI driver and a storage class for a Hetzner
Storage Box. Host-side SMB mounts can be managed with Ansible. An external NAS
is proposed and is not documented as deployed.

## Configuration overview

Kubernetes storage and its external-secret reference are in
`kubernetes/argo/manifests/storage.yaml`. Host mounts are under
`ansible/playbooks/storage/`.

## Deployment notes

Hosts require CIFS utilities. Confirm the share, secret reference, reclaim
policy, access modes, and workload expectations before provisioning.

## Upgrade procedure

Review CSI compatibility, back up important data, upgrade the driver, and test
new and existing mounts.

## Troubleshooting

Check ExternalSecret readiness, CSI pods, host packages, PVC events, SMB
reachability, and permissions. Never overwrite the only copy during a test.

## Live configuration

- [Kubernetes SMB storage](../../../kubernetes/argo/manifests/storage.yaml)
- [Ansible mount playbook](../../../ansible/playbooks/storage/mount.yml)
- [Mount variables](../../../ansible/playbooks/storage/vars/mounts.yml)
