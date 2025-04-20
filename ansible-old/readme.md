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
ansible pvenodes -i inventory -m ping --user=root -k
```

### Ping machines via ansible using an ssh-key as the reference

```shell
ansible pvenodes -m ping -i inventory/static.yaml --user=ansible --private-key ~/.ssh/<key>
```