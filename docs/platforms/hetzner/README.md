# Hetzner Platform

## Architecture overview

Hetzner supplies compute referenced by Ansible inventory and a Storage Box used
by Kubernetes. Historical docs refer to dedicated Proxmox hosting, but its
current runtime status has not been verified.

## Configuration overview

The active inventory group contains `chaos` and `hermes`; addresses come from
1Password lookups. Kubernetes VPS documentation sits beside its code.

## Deployment notes

Provisioning is not represented as Terraform or OpenTofu. Record server role,
region, firewall, and recovery access in a non-secret inventory before Ansible
onboarding.

## Upgrade procedure

Use Ansible check mode where supported, validate recovery points, and schedule
disruptive operating-system or K3s work.

## Troubleshooting

Verify provider status and console access, then network, inventory resolution,
SSH, host services, and cluster status.

## Live configuration

- [Inventory](../../../ansible/inventory/inventory.yml)
- [VPS documentation](../../../kubernetes/vps/)
- [Ansible](../../../ansible/)

TODO: Verify which hosts and legacy dedicated-server details are current.
