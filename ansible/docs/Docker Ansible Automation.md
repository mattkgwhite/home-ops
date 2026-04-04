# Docker Ansible Automation
## Configuration Reference & Quick-Start Guide

---

## 1. Purpose

This Ansible project automates the installation and management of Docker and Docker Compose across multiple Linux distributions. It is structured so that each concern (installation, daemon configuration, compose deployment, container management) is independent and can be run on its own or combined via a central entry point.

---

## 2. Folder Structure

All files live under a top-level `docker/` directory. The layout follows Ansible conventions, separating play-level logic (`playbooks/`) from reusable task logic (`tasks/`).

```
docker/
├── main.yml                          # Central entry point
├── inventory/
│   ├── hosts.ini                     # Target host definitions
│   └── group_vars/
│       └── all.yml                   # Shared variable defaults
├── playbooks/
│   ├── install_docker.yml
│   ├── configure_daemon.yml
│   ├── deploy_compose.yml
│   └── manage_containers.yml
├── tasks/
│   ├── install_docker.yml
│   ├── configure_daemon.yml
│   ├── deploy_compose.yml
│   ├── github_checkout.yml
│   └── manage_containers.yml
└── compose_files/
    ├── nginx/
    │   └── docker-compose.yml
    ├── postgres/
    │   └── docker-compose.yml
    └── myapp/
        └── docker-compose.yml
```

| Path | Purpose |
|---|---|
| `docker/main.yml` | Central entry point — import/uncomment plays as needed |
| `docker/inventory/hosts.ini` | Target host definitions and connection settings |
| `docker/inventory/group_vars/all.yml` | Shared variable defaults for all plays |
| `docker/playbooks/` | Play-level files — define hosts, prompts, and validations |
| `docker/tasks/` | Reusable task files — pure logic, no host binding |
| `docker/compose_files/` | Local compose file library, one subfolder per stack |

---

## 3. Playbooks

Each playbook is self-contained and independently runnable. They handle prompts, pre-task validation, and delegate the actual work to task files.

| Playbook | What it does |
|---|---|
| `install_docker.yml` | Installs Docker CE and Docker Compose plugin via `geerlingguy.docker`. Auto-detects OS family and package manager. |
| `configure_daemon.yml` | Writes `/etc/docker/daemon.json` with a custom data-root path. Safely migrates existing data via rsync before removing the old directory. |
| `deploy_compose.yml` | Copies a compose file to the remote host and brings the stack up. Source can be a local file or a GitHub repo. |
| `manage_containers.yml` | Runs `start` / `stop` / `restart` / `pull` / `status` against a named compose stack that has already been deployed. |

---

## 4. Task Files

Task files contain no host references and can be included by any playbook. This means logic is written once and reused rather than duplicated.

| Task file | Responsibility |
|---|---|
| `install_docker.yml` | Runs the `geerlingguy.docker` role, starts/enables the service, verifies CLI versions. |
| `configure_daemon.yml` | Stops services, writes `daemon.json`, migrates data-root, restarts services. |
| `deploy_compose.yml` | Validates the compose file exists, copies it to `/opt/compose/<project>/`, pulls images, runs `docker compose up`. |
| `github_checkout.yml` | Clones a GitHub repo to `/tmp` on the control node, verifies the compose file exists inside it, sets `compose_file_path` as a fact. |
| `manage_containers.yml` | Conditionally runs the correct `docker compose` command based on the `container_action` variable. |

---

## 5. Compose File Library

The `compose_files/` directory stores local compose configurations. Each stack gets its own subfolder. Adding a new stack means adding a new folder — no playbook changes required.

```
docker/compose_files/
├── nginx/
│   └── docker-compose.yml
├── postgres/
│   └── docker-compose.yml
└── myapp/
    └── docker-compose.yml
```

When deploying locally, pass the relative path to the compose file as the `compose_file_path` prompt value, or via `-e` on the command line.

---

## 6. OS and Package Manager Support

OS detection is handled automatically by Ansible's `gather_facts` and the `geerlingguy.docker` role. The install playbook validates the OS family before running and prints detected info at the start of every play.

| OS Family | Distributions / Package Manager |
|---|---|
| `Debian` | Ubuntu, Debian — `apt` |
| `RedHat` | RHEL, Rocky, AlmaLinux, Fedora — `dnf` / `yum` |
| `Suse` | openSUSE, SLES — `zypper` |
| `Archlinux` | Arch Linux — `pacman` |

---

## 7. Key Variables

Defaults are set in `docker/inventory/group_vars/all.yml` and can be overridden per host, per group, or at the command line with `-e`.

| Variable | Default / Purpose |
|---|---|
| `docker_daemon_path` | `/var/lib/docker` — custom data-root location |
| `docker_log_driver` | `json-file` |
| `docker_log_max_size` | `10m` |
| `docker_log_max_file` | `3` |
| `compose_project_name` | `myproject` — name passed to `docker compose -p` |
| `compose_dest_base` | `/opt/compose` — remote base path for deployed stacks |
| `github_repo_branch` | `main` |
| `compose_file_in_repo` | `docker-compose.yml` — path within the cloned repo |

---

## 8. Quick-Start Commands

Install the role dependency before first use:

```bash
ansible-galaxy role install geerlingguy.docker
```

| Goal | Command |
|---|---|
| Install Docker only | `ansible-playbook docker/playbooks/install_docker.yml -i docker/inventory/hosts.ini` |
| Configure daemon | `ansible-playbook docker/playbooks/configure_daemon.yml -i docker/inventory/hosts.ini` |
| Deploy local compose | `ansible-playbook docker/playbooks/deploy_compose.yml -i docker/inventory/hosts.ini` |
| Deploy from GitHub | See section 9 below |
| Restart a stack | `ansible-playbook docker/playbooks/manage_containers.yml -i docker/inventory/hosts.ini -e "compose_project_name=nginx" -e "container_action=restart"` |
| Check stack status | `ansible-playbook docker/playbooks/manage_containers.yml -i docker/inventory/hosts.ini -e "compose_project_name=nginx" -e "container_action=status"` |
| Run via main.yml | `ansible-playbook docker/main.yml -i docker/inventory/hosts.ini` |
| Dry run (no changes) | Add `--check --diff` to any command above |

---

## 9. GitHub as a Compose Source

When `use_github_repo=yes`, the `github_checkout` task file:

- Clones the repo to `/tmp/ansible-compose-<project>` on the control node
- Verifies the compose file exists at the path specified by `compose_file_in_repo`
- Sets `compose_file_path` as a fact so `deploy_compose.yml` picks it up transparently
- Cleans up the `/tmp` clone after deployment completes

The `compose_files/` folder in the repo serves as the library, with individual stacks referenced by subfolder path:

```bash
ansible-playbook docker/playbooks/deploy_compose.yml -i docker/inventory/hosts.ini \
  -e "use_github_repo=yes" \
  -e "github_repo_url=https://github.com/org/repo.git" \
  -e "compose_file_in_repo=compose_files/nginx/docker-compose.yml" \
  -e "compose_project_name=nginx"
```

---

## 10. Adding a New Compose Stack

No playbook changes are needed. Simply:

1. Create a new subfolder under `docker/compose_files/`
2. Add a `docker-compose.yml` inside it
3. Deploy using the project name matching the subfolder name

Example — adding a Grafana stack:

```bash
mkdir docker/compose_files/grafana
# add docker/compose_files/grafana/docker-compose.yml

ansible-playbook docker/playbooks/deploy_compose.yml -i docker/inventory/hosts.ini \
  -e "compose_project_name=grafana" \
  -e "compose_file_path=docker/compose_files/grafana/docker-compose.yml"
```

---

## 11. Notes

- Deployed compose stacks are copied to `/opt/compose/<project_name>/docker-compose.yml` on the remote host
- The daemon reconfiguration block uses `rsync` to migrate data before deleting the old directory — it will not delete `/var/lib/docker` until the rsync succeeds
- All playbooks support non-interactive mode — pass any prompted value via `-e` to bypass prompts entirely
- The `manage_containers` playbook expects the stack to already be deployed; it operates on the remote copy at `/opt/compose/`
- Run any playbook with `--check --diff` first on a new host to preview changes without applying them