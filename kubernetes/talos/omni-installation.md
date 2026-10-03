# Connect existing Talos nodes to Omni

Runbook from the successful connection work on **2 October 2026**. It includes today's commands and configuration changes, excluding the `/etc/hosts` read command. Initial Talos installation and the earlier Kubernetes version patch are prerequisites, outside this runbook.

Both nodes were visible in Omni at the end of this session. This confirms machine connectivity; it does not confirm that the cluster was unlocked or upgraded by Omni.

## Environment and prerequisites

| Machine | Role | Public address used today |
| --- | --- | --- |
| `talos-iwd-lqp` | Control plane | `<control-ip>` |
| `talos-oc7-jd1` | Worker | `<worker-ip>` |
| Docker VPS | Omni and Tailscale | Private IP `172.16.0.3` |

- Existing Kubernetes cluster: `olumpus`, with Talos `1.13.7` and Kubernetes `1.31.0` observed during import.
- Omni hostname: `omni.<tail-net>.ts.net`.
- Omni container: `omni`; Tailscale container: `tailscale-omni`.
- Omni uses `network_mode: service:tailscale`.
- The machine API on port 8090 serves a certificate signed by `Internal Root CA`.
- Local commands assume the working directory contains `talosconfig`, `omniconfig.yaml`, and `omni-access-patch.yaml`. If using the repository's `patches/` directory, change the patch argument to `@./patches/omni-access-patch.yaml`.
- Download a current `omniconfig.yaml` from the Omni dashboard. Use the existing cluster's administrator `talosconfig`.
- After a rebuild, replace addresses and hostnames if they change. Discover the new node UUIDs instead of relying on the old ones.

The node role mapping was confirmed with:

```sh
kubectl get nodes -o custom-columns='NAME:.metadata.name,ROLE:.metadata.labels.node-role\.kubernetes\.io/control-plane,UUID:.status.nodeInfo.systemUUID'
```

Recorded UUIDs: control plane `3fc114f8-f224-4853-b6b7-ae9d948bc11c`; worker `a35a6381-0b04-4a60-9576-abb605a22f27`.

## 1. Expose the machine API and WireGuard through Tailscale's container

Add these mappings to the **Tailscale service**, alongside its existing ports. Omni shares that service's network namespace, so port publishing belongs there.

```yaml
services:
  tailscale:
    ports:
      - "172.16.0.3:8090:8090/tcp"
      - "172.16.0.3:50180:50180/udp"

  omni:
    network_mode: service:tailscale
```

These are additions to the existing Compose definition. Preserve all other settings. Recreate the affected services using your existing Compose deployment process. Recreate Omni with Tailscale so it uses the current container's network namespace.

Omni must listen on `0.0.0.0:8090` for its machine API and `0.0.0.0:50180` for WireGuard inside the shared namespace. The WireGuard endpoint advertised to these nodes was `172.16.0.3:50180`.

On the Docker VPS, verify the mappings:

```sh
docker port tailscale-omni
```

Expected:

```text
8090/tcp -> 172.16.0.3:8090
50180/udp -> 172.16.0.3:50180
```

Check that Omni references the current Tailscale container:

```sh
docker inspect omni --format '{{.HostConfig.NetworkMode}}'
docker inspect tailscale-omni --format '{{.Id}}'
```

The first output should be `container:<id>`, matching the second output.

## 2. Locate and inspect Omni's public CA certificate

Run these commands on the Docker VPS.

Find the mounted certificate paths:

```sh
docker inspect omni \
  --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

The certificate mounts used today were:

```text
/home/<user>/compose/omni/certs/server-chain.pem -> /server-chain.pem
/home/<user>/compose/omni/certs/server-key.pem -> /server-key.pem
/home/<user>/compose/omni/certs/combined-ca-certificates.crt -> /etc/ssl/certs/ca-certificates.crt
```

List the directory:

```sh
lsd /home/<user>/compose/omni/certs
```

The following command inspected only the first certificate in the combined bundle, which was an Entrust root rather than Omni's internal CA:

```sh
openssl x509 \
  -in /home/<user>/compose/omni/certs/combined-ca-certificates.crt \
  -noout -subject -issuer -ext basicConstraints
```

List the certificates in Omni's server chain:

```sh
openssl crl2pkcs7 -nocrl \
  -certfile /home/<user>/compose/omni/certs/server-chain.pem |
  openssl pkcs7 -print_certs -noout
```

The chain contained `Internal Wildcard`, followed by the self-signed `Internal Root CA`. The `-noout` option hides the PEM certificate contents; it does not indicate an empty file.

Print the public certificates, including their PEM blocks:

```sh
openssl crl2pkcs7 -nocrl \
  -certfile /home/<user>/compose/omni/certs/server-chain.pem |
  openssl pkcs7 -print_certs
```

Copy the complete PEM block whose subject is `Internal Root CA`. It was the **second certificate** in today's chain. Verify the identity again after rebuilding rather than assuming the order stays the same. Do not copy a private key or `omni.asc`.

## 3. Configure hostname resolution and CA trust on both nodes

Create `omni-access-patch.yaml` locally with the following contents. Replace the certificate placeholder with the actual root CA certificate from step 2, preserving indentation.

```yaml
apiVersion: v1alpha1
kind: StaticHostConfig
name: 172.16.0.3
hostnames:
  - omni.<tail-net>.ts.net
---
apiVersion: v1alpha1
kind: TrustedRootsConfig
name: omni-internal-ca
certificates: |
  -----BEGIN CERTIFICATE-----
  REPLACE_WITH_ROOT_CA_CERTIFICATE_CONTENT
  -----END CERTIFICATE-----
```

The static mapping lets Talos reach Omni directly over the Hetzner private network while retaining the hostname used by the TLS certificate. The CA document adds trust for that certificate's issuer.

Apply to the **control plane**:

```sh
talosctl patch machineconfig \
  --talosconfig ./talosconfig \
  --endpoints <control-ip> \
  --nodes <control-ip> \
  --patch @./omni-access-patch.yaml
```

Apply to the **worker**:

```sh
talosctl patch machineconfig \
  --talosconfig ./talosconfig \
  --endpoints <worker-ip> \
  --nodes <worker-ip> \
  --patch @./omni-access-patch.yaml
```

Direct access to each node avoids the `no request forwarding` error seen when routing worker requests through the control plane. Both patches returned `Applied configuration without a reboot`. SideroLink retries automatically.

## 4. Authenticate the local Omni CLI

On the local machine, using the downloaded `omniconfig.yaml`:

```sh
omnictl \
  --omniconfig ./omniconfig.yaml \
  --insecure-skip-tls-verify \
  get clusters
```

Complete browser sign-in. During today's first login, a missing `default-admin@omni.pgp` message was followed by browser authentication and creation of the local key. An empty clusters table was expected before import.

`--insecure-skip-tls-verify` was the temporary workaround for the local CLI not trusting Omni's internal CA. It disables verification of the Omni endpoint; it does not configure trust on Talos. Remove it once local trust is configured.

## 5. Import the existing Kubernetes cluster

These nodes already had full control-plane/worker machine configurations. Applying ordinary join documents alone resulted in Omni's pending-machine controller receiving `tls: certificate required`. Use the existing-cluster import flow with its current credentials.

Preview:

```sh
omnictl \
  --omniconfig ./omniconfig.yaml \
  --insecure-skip-tls-verify \
  cluster import \
  --talosconfig ./talosconfig \
  --talos-endpoints <control-ip> \
  --nodes "<control-ip>,<worker-ip>" \
  --force \
  --dry-run
```

`--force` was added because validation reported missing Image Factory schematic IDs on both nodes. For installations with valid schematics, first preview without it. With this override, future Omni upgrades use a newly generated schematic; review required extensions and boot settings before upgrading.

After a successful preview, perform the import:

```sh
omnictl \
  --omniconfig ./omniconfig.yaml \
  --insecure-skip-tls-verify \
  cluster import \
  --talosconfig ./talosconfig \
  --talos-endpoints <control-ip> \
  --nodes "<control-ip>,<worker-ip>" \
  --force
```

Import saves a backup and registers the cluster locked for review. Retain the backup securely: machine configurations contain credentials. Do not start a duplicate import merely because the dashboard shows `importing` or `scaling up`; inspect the current command output and logs.

## 6. Verify both machines connected

```sh
omnictl \
  --omniconfig ./omniconfig.yaml \
  --insecure-skip-tls-verify \
  get machines
```

Confirm two machines with `CONNECTED true`, and compare their UUIDs with the Kubernetes mapping above. Both should appear in Omni's Machines view. A successful import command reports that `olumpus` was imported and marked locked. Unlocking and upgrades are outside today's completed command sequence.

## Diagnostics used today

### Test private-network TCP and TLS connectivity

Create a diagnostic shell on the control plane:

```sh
kubectl debug node/talos-iwd-lqp \
  --namespace kube-system \
  --image=curlimages/curl \
  --profile=general \
  -it -- sh
```

Inside that shell:

```sh
curl -v --connect-timeout 5 --max-time 10 \
  --resolve 'omni.<tail-net>.ts.net:8090:172.16.0.3' \
  'https://omni.<tail-net>.ts.net:8090/'
```

For the worker, use `node/talos-oc7-jd1` in the debug command. `--resolve` bypasses DNS for this request only. Initially the connection was refused; after exposing 8090, TLS responded but the diagnostic container rejected the internal CA. That container has its own trust store, independent of Talos's `TrustedRootsConfig`.

After exiting the shell, remove the debug pod using the actual name printed by `kubectl debug`:

```sh
kubectl delete pod -n kube-system <debug-pod-name>
```

### Inspect Docker listeners and Omni errors

On the Docker VPS:

```sh
sudo ss -lntup
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

```sh
docker logs --since 5m omni 2>&1 |
  rg -i 'import|pendingmachine|siderolink|handshake|certificate|error'
```

### Inspect Talos connection errors

Control plane:

```sh
talosctl logs machined \
  --talosconfig ./talosconfig \
  --endpoints <control-ip> \
  --nodes <control-ip> \
  --tail 2000 |
  rg -i 'siderolink|provision|resolve|timeout|refused|certificate'
```

Worker:

```sh
talosctl logs machined \
  --talosconfig ./talosconfig \
  --endpoints <worker-ip> \
  --nodes <worker-ip> \
  --tail 100 |
  rg -i 'siderolink|wireguard|provision|resolve|timeout|refused|certificate'
```

An empty filtered result means no matching lines in that log window. Check timestamps before interpreting old failures. Redact join tokens before sharing logs.

Inspect the control plane's interfaces:

```sh
talosctl get links \
  --talosconfig ./talosconfig \
  --endpoints <control-ip> \
  --nodes <control-ip>
```

| Symptom observed | Resolution used |
| --- | --- |
| `name resolver error: produced zero addresses` | Apply the Omni hostname mapping to the affected node. |
| Connection refused on private TCP 8090 | Publish 8090 on the Tailscale service and ensure the machine API listens. |
| Internal CA not trusted | Add the issuing public root CA to Talos with `TrustedRootsConfig`. |
| Tunnel configured but connectivity unconfirmed | Publish UDP 50180 and check Omni logs. |
| Pending-machine `tls: certificate required` | Import the configured cluster using its administrator `talosconfig`. |
| Missing local Omni PGP key | Complete browser authentication with `omnictl get clusters`. |
| Missing Image Factory schematic IDs | Preview import with `--force`, then import after reviewing the result. |

## References

- [Omni cluster import](https://docs.siderolabs.com/omni/cluster-management/importing-talos-clusters)
- [Talos StaticHostConfig](https://docs.siderolabs.com/talos/v1.13/reference/configuration/network/statichostconfig)
- [Talos TrustedRootsConfig](https://docs.siderolabs.com/talos/v1.13/reference/configuration/security/trustedrootsconfig)
