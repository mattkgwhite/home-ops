# Move External Secrets onto the worker

The control plane, `talos-iwd-lqp`, already has the `node-role.kubernetes.io/control-plane:NoSchedule` taint. The live `argocd/external-secrets` Application sets a global Helm `nodeSelector` that requires that hostname and a toleration that permits scheduling there. The selector pins the operator, cert controller, and webhook to the control plane; the toleration lets them through the taint. See [Kubernetes scheduling rules](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/).

Kubernetes field ownership attributes both overrides to a `kubectl-patch` update on 16 October 2026. Argo CD then rendered them into all three deployments. The overrides are absent from the [Git manifest](../../kubernetes/argo/manifests/external-secrets.yaml) and the revision Argo CD synced during the investigation. The parent Application manages `installCRDs` but does not own the live `global` block, so another Git sync alone won't remove it.

## Change

Keep the existing taint. Remove only `/spec/source/helm/valuesObject/global` from the live `argocd/external-secrets` Application. Use a JSON Patch `test` operation to confirm the block still contains exactly the selector and toleration below before removing it. Save the block for rollback.

```yaml
global:
  nodeSelector:
    kubernetes.io/hostname: talos-iwd-lqp
  tolerations:
    - effect: NoSchedule
      key: node-role.kubernetes.io/control-plane
      operator: Exists
```

The server dry run passed during planning. Rendering the installed chart without the override confirmed that all three deployments have no node selector, affinity, or toleration. Let Argo CD roll them onto `talos-oc7-jd1`, the only eligible node at the time of the investigation. No Git configuration change or worker hostname pin is needed.

## Verify the move

1. Confirm the new replicas for `external-secrets`, `external-secrets-cert-controller`, and `external-secrets-webhook` are Ready on `talos-oc7-jd1`, the webhook has a ready worker endpoint, and the Application is `Synced` and `Healthy`.
2. Repeat the server dry-run updates against `authelia/ExternalSecret/authelia-config` and `ClusterSecretStore/1password`. These checks passed before the move and should pass after the webhook endpoint switches to the worker.
3. Confirm `authelia-config` reports a refresh after the rollout and the `1password`, `vaultwarden-fields`, and `vaultwarden-login` cluster stores remain Ready.

The webhook fails closed, and the [Talos runbook](talos.md#repeated-dns-rollouts-and-remote-node-api-access) documents past worker networking problems. Pod readiness alone does not verify admission or secret refreshes.

## Rollback

If the deployments fail to roll out, webhook admission fails, or the test secret stops refreshing, restore the exact saved `global` block on the same Application. Verify the three deployments, webhook admission, and secret refresh recover. Keep this change limited to External Secrets.
