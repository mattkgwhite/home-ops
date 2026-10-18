# Gotify

[The Gotify manifest](../../kubernetes/argo/manifests/gotify.yaml) defines an Argo CD Application using the community-maintained [gabe565 Gotify Helm chart](https://charts.gabe565.com/charts/gotify/), pinned to chart version `0.4.0`. The container image is independently pinned to `ghcr.io/gotify/server:3.1.1`.

The manifest ApplicationSet registers `gotify.yaml`. Its parent Application manages the namespace, PVC, service account, Tailscale ingress and Helm Application. The Helm Application manages Gotify's Deployment and Service.

The chart references the existing `gotify-data` PVC rather than creating another claim. The claim requests `10Gi` from `hcloud-volumes` with `ReadWriteOnce`. A single replica and `Recreate` strategy prevent overlapping pods during normal updates. Gotify runs as UID/GID `1000`, with `fsGroup: 1000`, on container port `8080`; the Service retains port `80`. The ingress retains the Tailscale hostname `gotify`.

## Handoff from the raw Deployment

The chart's Deployment selector uses `app.kubernetes.io/name` and `app.kubernetes.io/instance`, whereas the raw Deployment uses `app: gotify`. Kubernetes cannot change that selector in place, so replace only the old Deployment once before the first Helm Application sync. This causes a brief interruption.

1. Confirm that `gotify-data` is already bound to the intended Cloud Volume:

   ```zsh
   mise x -- kubectl get pvc gotify-data -n gotify -o wide
   ```

   The storage class must be `hcloud-volumes` and the status must be `Bound`. If it still uses `hetzner-storagebox`, complete the storage migration first. Changing the PVC manifest cannot migrate a bound claim or copy its data.

2. Stop the old Deployment and wait for its pods to terminate:

   ```zsh
   mise x -- kubectl scale deployment/gotify -n gotify --replicas=0
   mise x -- kubectl wait --for=delete pod -n gotify -l app=gotify --timeout=180s
   ```

3. After the wait succeeds, delete only the old Deployment:

   ```zsh
   mise x -- kubectl delete deployment gotify -n gotify --cascade=foreground --wait=true
   ```

   Keep the namespace and `gotify-data` PVC. Do not delete all resources from the former manifest.

4. Make the updated manifests available in the Git revision watched by Argo CD, reconcile the manifest ApplicationSet, and sync the Gotify Applications. The new Deployment mounts the same claim. Helm rendering through Argo CD does not require a separate `helm install`.

5. Verify the rollout and Service endpoints:

   ```zsh
   mise x -- kubectl rollout status deployment/gotify -n gotify --timeout=180s
   mise x -- kubectl get endpointslices -n gotify -l kubernetes.io/service-name=gotify
   mise x -- kubectl get ingress gotify-tailscale -n gotify
   ```
