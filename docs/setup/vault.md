# OpenBao

Argo CD deploys OpenBao as a single StatefulSet replica named `openbao` in the `vault` namespace. The Argo CD Application remains named `vault` and is defined in `kubernetes/argo/manifests/vault.yaml`.

OpenBao uses file storage at `/openbao/data` on the `data-openbao-0` persistent volume claim. The claim requests 10 GiB with ReadWriteOnce access using the `hetzner-storagebox` storage class. This deployment starts with fresh data and requires new initialization keys.

## Initialize and unseal in the UI

Open [OpenBao on Tailscale](https://vault.rat-shilling.ts.net/ui/) from a device with tailnet access.

1. Initialize the new OpenBao instance in the UI. Store the unseal shares and initial root token securely.
2. Enter a different unseal share for each submission until you reach the configured threshold.
3. Sign in using the initial root token to configure authentication and access policies.

The readiness and liveness probes use `/v1/sys/health?sealedcode=200&uninitcode=200`. This keeps the UI reachable through the Tailscale ingress while OpenBao is sealed or uninitialized. Pod readiness indicates that the HTTP endpoint is available. Use `bao status` to check the actual seal state.

After a restart, use the UI to unseal OpenBao again. If it is already initialized, continue with the unseal step.

If the ingress is unavailable, forward directly to the pod:

```sh
mise x -- kubectl port-forward -n vault pod/openbao-0 8200:8200
```

Keep the command running and open [the local OpenBao UI](http://localhost:8200/ui/).

## Initialize and unseal from the CLI

Initialize only a new OpenBao instance:

```sh
mise x -- kubectl exec -n vault openbao-0 -- bao operator init
```

Store the generated unseal shares and initial root token securely. Run the following command once per required share and enter a different share at each prompt:

```sh
mise x -- kubectl exec -it -n vault openbao-0 -- bao operator unseal
```

Check the seal status and pod readiness:

```sh
mise x -- kubectl exec -n vault openbao-0 -- bao status
mise x -- kubectl get pod -n vault openbao-0
```
