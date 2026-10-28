# Vaultwarden and External Secrets Operator

Vaultwarden exposes the Bitwarden Password Manager API. ESO's Bitwarden Secrets
Manager provider uses a different API. This deployment follows ESO's documented
Password Manager integration with a Bitwarden CLI bridge and webhook stores.

```text
1Password -> ESO -> vaultwarden-cli credentials Secret
Vaultwarden <- Bitwarden CLI bridge <- ESO webhook stores -> application Secrets
```

The bridge connects to `http://vault-warden.vaultwarden.svc.cluster.local`.
The stores connect to `http://vaultwarden-cli.vaultwarden.svc.cluster.local:8087`.
These use Kubernetes Services; the Tailscale hostname is not involved.

## Create the bridge account

1. Create a dedicated account in your deployed Vaultwarden instance. Do not use
   your personal vault account for the bridge.
2. Give that account access only to the application credentials ESO needs. If
   using an organization, accept the invitation, confirm the member, and grant
   access to the appropriate collection. Prefer read-only collection access.
3. Sign in as that account and open **Settings -> Security -> Keys -> View API
   key**. Record its personal `client_id` and `client_secret` in 1Password.
   This is not the Vaultwarden admin token or an organization API key.
4. In the `homelab` vault already accessible to the `1password` ClusterSecretStore,
   create an item named `vaultwarden-cli` with these fields:

   | 1Password field | Value |
   | --- | --- |
   | `client_id` | The bridge account's personal API client ID |
   | `client_secret` | The bridge account's personal API client secret |
   | `master_password` | The bridge account's master password |

Use password/concealed fields for the client secret and master password. Do not
put their values in Git, command arguments, or chat. The `ExternalSecret` in
`kubernetes/argo/manifests/vaultwarden.yaml` maps these fields into the runtime
credentials Secret.

API-key login supports unattended authentication, including accounts with 2FA.
The master password is still required to decrypt the vault. No additional
Vaultwarden server flag is required for the CLI integration.

## Deploy through Argo CD

1. Commit and push `vaultwarden.yaml` and `external-secrets.yaml` after review.
2. Refresh and sync the `vaultwarden` application. Its manifest includes the
   credentials ExternalSecret, CLI Deployment, internal Service, ServiceAccount,
   and NetworkPolicy. The policy permits port 8087 only from the ESO controller
   pods in the `external-secrets` namespace.
3. Apply the two new stores from the reviewed manifest:

   ```sh
   mise x -- yq eval-all 'select(.kind == "ClusterSecretStore" and (.metadata.name == "vaultwarden-login" or .metadata.name == "vaultwarden-fields"))' kubernetes/argo/manifests/external-secrets.yaml | mise x -- kubectl apply -f -
   ```

   The existing `1password` store has no Argo tracking annotation or instance
   label, and this file is not included in the repository's ApplicationSet.
   The `external-secrets` Helm Application deploys the operator; syncing only
   that Helm chart does not deploy sibling YAML resources. The filtered apply
   above adds only these stores and does not upgrade the operator's Helm release.
4. Check readiness without displaying secret values:

   ```sh
   mise x -- kubectl get externalsecret vaultwarden-cli -n vaultwarden
   mise x -- kubectl rollout status deployment/vaultwarden-cli -n vaultwarden
   mise x -- kubectl get clustersecretstore vaultwarden-login vaultwarden-fields
   ```

The bridge's `bw serve` API has no caller authentication and must remain internal.
Keep the NetworkPolicy in place and do not add an Ingress or Tailscale exposure
for the CLI Service. The existing Vaultwarden web Ingress remains unchanged.

## Read a vault item

Use the item's UUID from its web-vault URL (`itemId`), rather than its title, as
`remoteRef.key`. Use the relevant store for the type of field being requested:

| Store | `remoteRef.property` |
| --- | --- |
| `vaultwarden-login` | `username` or `password` |
| `vaultwarden-fields` | The exact custom field name, such as `token` |

For example, place an ExternalSecret like this in the application's manifest,
replacing the namespace and item UUID before deployment:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: application-credentials
  namespace: your-application
spec:
  refreshInterval: "5m"
  secretStoreRef:
    kind: ClusterSecretStore
    name: vaultwarden-fields
  target:
    creationPolicy: Owner
  data:
    - secretKey: token
      remoteRef:
        key: replace-with-item-uuid
        property: token
```

Do not migrate existing ExternalSecrets until a test item syncs successfully.
The existing `1password` store and its consumers remain configured as before.

## Refresh and credential rotation

The bridge pulls vault changes through its sync probe every two minutes; ESO
then refreshes each ExternalSecret on that object's configured interval. The
CLI cache is ephemeral and the bridge logs in again after a restart.

If the bridge account's API key or master password changes, update the 1Password
item, wait for its ExternalSecret to refresh, then restart the CLI Deployment.
The credential environment variables are loaded at container startup.

```sh
mise x -- kubectl rollout restart deployment/vaultwarden-cli -n vaultwarden
mise x -- kubectl rollout status deployment/vaultwarden-cli -n vaultwarden
```

## References

- [ESO Password Manager integration, including Vaultwarden](https://external-secrets.io/latest/examples/bitwarden/)
- [ESO Bitwarden Secrets Manager provider](https://external-secrets.io/latest/provider/bitwarden-secrets-manager/)
- [Bitwarden CLI authentication with a personal API key](https://bitwarden.com/help/personal-api-key/)
- [Bitwarden CLI reference](https://bitwarden.com/help/cli/)
