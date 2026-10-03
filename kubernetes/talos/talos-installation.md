# Talos

Below are instructions that appear to work at the time of writing them to specifically setup / create a talos node
Reference official install documentation:https://docs.siderolabs.com/talos/v1.14/getting-started/getting-started
Reference official older version documentation: https://docs.siderolabs.com/talos/v1.9/getting-started/getting-started

## Generating config

generate a configuration: `talosctl gen config <cluster-name> https://<cluster-ip>`
- <cluster-name>: name of the cluster
- <cluster-ip>: this is the public ip of the VPS / or internal lan ip

## Applying configuration

`taloctl apply-config --insecure -n <cluster-ip> --file controlpanel.yaml`
- controlpanel.yaml - this is one of the files that is generated as part of the configuration.

## Check disks

`talosctl apply-config --insecure -n <cluster-ip> --file controlplane.yaml`

## Bootstrap configuration

`talosctl bootstrap --nodes <cluster-ip> --endpoints <cluster-ip> --talosconfig=./talosconfig`

## Kubernetes Config

Running the below command will replace any existing kubernetes config (kubeconfig) file with the new configuration.

`talosctl kubeconfig --nodes <cluster-ip> --endpoints <cluster-ip> --talosconfig=./talosconfig`

Running the below command to not have your existing configuration be merged into the default kubernetes configuration file, need to pass in a filename.

`talosctl kubeconfig <file-name> --nodes <cluster-ip> --endpoints <cluster-ip> --talosconfig=./talosconfig`

## Patching the control-plane after initial install

```shell
talosctl patch machineconfig \
  --talosconfig ./talosconfig \
  --endpoints <worker-ip> \
  --nodes <worker-ip> \
  --patch @./kubernetes-version-patch.yaml \
  --patch @./machine-config.yaml
```

### Talos Queries

- Query `cluster status` with added authentication from browser:
  - `omnictl --omniconfig ./omniconfig.yaml --insecure-skip-tls-verify cluster status olumpus --wait=0`

