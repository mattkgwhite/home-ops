# Ansible

## Requirements

sshpass - required to prompt for a password at execution

```shell
sudo apt install sshpass -y
```

## Sample Commands

### Ping machines via ansible as the root user, prompting for password at execution
The below commands uses the inventory file called `static.yaml` as a reference, pinging the host / hosts listed under `[pvenodes]` using the root account via `--user=root` and prompting for a password `-k`

```shell
ansible pvenodes -i inventory -m ping --u <user> 
```

An alternative to the above example command:
```shell
ansible all -i inventory -m ping
```

### Ping machines via ansible using an ssh-key as the reference

```shell
ansible pvenodes -m ping -i inventory/static.yaml --user=ansible --private-key ~/.ssh/<key>
```

Running a specific playbook, from within the playbooks directory of where playbook is stored. The command below also limits the target machine to be a specific one as defined in the ansible inventory file.

```shell
ansible-playbook -i ../../inventory/inventory.yml user.yml --limit viper --user root
```

### Secrets

```Shell
# 1password-cli is required
## https://developer.1password.com/docs/cli/get-started
# login via `eval $(op signin)`

export pve1="$(op read op://homelab/ansible/proxmox)" / Powershell example "$env:DOMAIN = & op read "op://homelab/ansible/proxmox" "
```

## Playbooks

For the specifics of using ansible-playbooks - there needs to be some way to list all the playbooks and tasks that are available.

Below is an example command

## Tasks

### Run against all hosts via main.yml

```shell
ansible-playbook -i Kubernetes/inventory/hosts.yml maintenance/tasks/main.yml
```

### Run against a specific OS only

```shell
ansible-playbook -i Kubernetes/inventory/hosts.yml maintenance/tasks/ubuntu.yml
```

### Run against a single host

```shell
ansible-playbook -i Kubernetes/inventory/hosts.yml maintenance/tasks/main.yml --limit vps1
```

### Just check, never apply (ask for password at execution to become relevant user to check for "updates")

```shell
ansible-playbook -i Kubernetes/inventory/hosts.yml maintenance/tasks/main.yml --check --ask-become-pass
```


### Structure

```
your-ansible-project/
├── Taskfile.yml           ← main entry point (vars + includes only)
└── taskfiles/
    ├── discovery.yml      ← list playbooks, roles, tags, hosts, tasks
    ├── playbooks.yml      ← run, check, diff, lint, env shortcuts
    ├── inventory.yml      ← list, graph, host vars
    ├── vault.yml          ← all vault operations
    ├── galaxy.yml         ← install, update, scaffold roles
    ├── adhoc.yml          ← ping, facts, ssh, uptime, disk, memory
    └── setup.yml          ← bootstrap, env-check, version, clean
```