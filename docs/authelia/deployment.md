# Authelia private evaluation deployment

Prepared: 2026-11-03. These manifests have been validated locally, not applied to the cluster.

## Configuration

The [Authelia manifest](../../kubernetes/argo/manifests/authelia.yaml) defines two manually synced Argo CD Applications:

- `authelia.manifest` manages this repository's Authelia file, including the namespace, secret references, database credential export, Tailscale Ingress, and Helm Application.
- `authelia` renders the official Helm chart `0.11.22` with application image `4.39.28`. The chart creates the Deployment, Service, ConfigMap, and ServiceAccount.

The portal uses the Tailscale hostname configured in the manifest, with Funnel disabled. Its session cookie is limited to that exact hostname. Existing application routes are unchanged. This does not yet enable native OIDC clients or protect other applications through Envoy.

There is one replica with in-memory sessions and a `Recreate` update strategy. A pod restart logs users out and interrupts portal access. PostgreSQL holds persistent MFA and identity-related state; a local PVC and Redis are not required for this evaluation.

The [shared PostgreSQL manifest](../../kubernetes/argo/manifests/postgres.yaml) adds a dedicated `authelia` database with its own generated account. It remains the sole owner of the PostgreSQL cluster definition. The Authelia manifest exports that account to 1Password using a PushSecret, then imports it into the Authelia namespace using an ExternalSecret.

Database connections use TLS with certificate verification disabled to match the existing self-signed Spilo certificate. Before a production rollout, establish certificate trust and remove `skip_verify`.

## Administration and notifications

Authelia's current stable release provides a login and MFA enrollment portal, not a user-administration console. `administration.enable_ui` appears in a [proposed administrator-console design](https://www.authelia.com/roadmap/active/dashboard-control-panel-and-cli-for-admins/) and is not a supported setting in this configuration. User accounts are managed in the 1Password-backed user file. A future console or directory migration must preserve one authoritative user store.

No SMTP service is configured. Enrollment and account-verification messages are written to `/config/notification.txt` inside the pod. Authelia recommends this [file notifier](https://www.authelia.com/configuration/notifications/file/) for testing only. Keep this deployment private while evaluating it; configure a production notification method before relying on it for public services.

The notification file contains sensitive verification links and codes. Retrieve it only in a private administrator terminal; do not paste it into chats, tickets, Git, or logs. It is on an ephemeral volume, so request a new enrollment message if a pod replacement removes it.

Self-service password changes and resets are disabled because the projected user Secret is read-only. Password recovery uses an independently accessible 1Password account and Kubernetes administrator credential.

## Prepare 1Password

Create an item named `authelia` in the vault used by the existing `1password` ClusterSecretStore:

| Property | Contents |
| --- | --- |
| `session_secret` | Independently generated random string of at least 64 characters |
| `storage_encryption_key` | Independently generated random string of at least 64 characters; retain with the database backup |
| `users_database` | Complete YAML user database, including password hashes |

Do not create the database credential item manually. The PostgreSQL operator generates the account; the PushSecret populates `postgres.cluster01.authelia.owner` with `username` and `password`.

Use this illustrative structure for the `users_database` property, replacing the placeholder hash and account metadata privately in 1Password:

```yaml
users:
  admin:
    displayname: Administrator
    password: '<replace with an Argon2id hash>'
    email: admin@example.com
    groups:
      - admins
```

The email field is account metadata even though no email is delivered in this evaluation. The `admins` group does not confer a built-in Authelia administrator role or grant Kubernetes permissions. Group-based access policies will be configured when onboarding applications.

Generate the hash interactively on a trusted machine with a running Docker daemon:

```zsh
mise x -- docker run --rm -it --entrypoint authelia \
  ghcr.io/authelia/authelia:4.39.28 \
  crypto hash generate argon2 --variant argon2id \
  --memory 65536 --iterations 3 --parallelism 4
```

Enter the password at the prompt rather than passing it as a command-line argument. Save only the resulting hash in the user database property. The [hashing flags](https://www.authelia.com/reference/cli/authelia/authelia_crypto_hash_generate_argon2/) use kibibytes for memory. Verification uses the cost encoded in each stored hash; the configured hashing settings do not reduce the cost of existing hashes. The initial 128 MiB memory request and 512 MiB limit need to be checked against measured login usage and concurrency.

## Deployment sequence

These steps change the live cluster and are provided for a later deployment. None have been executed as part of preparing the manifest.

1. Make the reviewed manifest changes available on the `main` branch used by Argo CD. Both Applications read from that branch, not this working tree.
2. Sync `postgres.manifest` so the PostgreSQL operator creates the Authelia database and account. Check that the existing database and dependent applications remain healthy.
3. Create the `authelia` 1Password item described above. Verify that the existing 1Password ClusterSecretStore, External Secrets controller, and Reloader are healthy.
4. Bootstrap only the parent Application from the repository root:

   ```zsh
   mise x -- yq 'select(.kind == "Application" and .metadata.name == "authelia.manifest")' kubernetes/argo/manifests/authelia.yaml | mise x -- kubectl apply -f -
   ```

5. Manually sync `authelia.manifest`. This creates its companion resources and the child Helm Application. The ApplicationSet does not need a new entry because this parent explicitly tracks the file.
6. Check the PushSecret and all three ExternalSecrets before syncing the Helm Application:

   ```zsh
   mise x -- kubectl get pushsecret cluster01.authelia.owner -n postgres
   mise x -- kubectl get externalsecrets -n authelia
   ```

   Continue only after the credential export and secret synchronization report success. Sync order between the PostgreSQL and Authelia Applications is a manual prerequisite, not an enforced cross-Application dependency.

7. Manually sync `authelia`. Verify the Deployment is Ready and the Tailscale operator has provisioned the portal Ingress:

   ```zsh
   mise x -- kubectl rollout status deployment/authelia -n authelia
   mise x -- kubectl get ingress authelia-tailscale -n authelia
   ```

   The provisioned hostname must match the session cookie configuration. Resolve any Tailscale name collision before testing authentication.

8. Open the portal while connected to the tailnet. Sign in, request enrollment, and inspect the verification message privately:

   ```zsh
   mise x -- kubectl exec -n authelia deployment/authelia -- cat /config/notification.txt
   ```

   Follow the current message's instructions and enroll TOTP. WebAuthn is also enabled; enroll a separate authenticator as a recovery option. No notification or credential contents should be added to this repository.

9. Test sign-in and MFA, then confirm that the portal is unreachable from a device outside the tailnet. Check the private hostname's TLS certificate and verify the lack of public exposure against the actual network configuration.

## Password recovery and ongoing changes

Generate a new password hash with the same interactive command, then update only the affected user's `password` field in the 1Password `users_database` property. Keep the username stable. Wait for the configured External Secrets refresh and confirm synchronization without printing the Secret's contents.

Reloader watches the managed Secrets and restarts Authelia when they change. Confirm a rollout after a password update; restarting the single replica clears its in-memory sessions. If Reloader does not trigger, investigate it or explicitly restart the Deployment after confirming the new Secret has synchronized.

Retain independent Kubernetes and 1Password recovery access. Recovering a lost second factor is a separate task from changing a password; preserve database backups and use the release-matched storage CLI when all enrolled authenticators are lost. Do not replace the storage encryption key or delete the database as a password/MFA reset procedure.

Back up the PostgreSQL database together with its storage encryption key and the user file. Adding replicas later also requires a shared session provider such as Redis; increasing the replica count alone is not supported by this configuration.

## Application onboarding follows separately

- For native OIDC, register the first client, configure persistent provider signing/HMAC keys through External Secrets, and configure the application's callback URL and group mappings. OIDC is not enabled with an empty client list in this initial deployment.
- For Envoy protection, establish the Gateway and matching Envoy CRDs first. Add a route-specific `SecurityPolicy`, a narrowly scoped cross-namespace ReferenceGrant when needed, and an explicit Authelia access rule for the target application. Use the chart-generated `authelia` Service on port 80 and `/api/authz/ext-authz/`.
- The current access rules allow only the portal hostname with a two-factor policy and deny other hosts. No policy is attached to the portal itself at the proxy, avoiding an authentication redirect loop.
- Proxy protection of applications under another domain requires a suitable cookie-domain and portal-hostname design. The portal's current host-only cookie cannot be shared with sibling Tailscale hostnames. Native OIDC uses redirects and does not require sharing that cookie with the application.
- A direct Tailscale route to an application bypasses Envoy authorization unless native authentication protects the application. Review all routes when adding gateway protection.

See the [research and deployment roadmap](plan.md), [Authelia chart documentation](https://charts.authelia.com/), [Kubernetes secrets integration](https://www.authelia.com/integration/kubernetes/secrets/), and [Envoy Gateway integration](https://www.authelia.com/integration/kubernetes/envoy/gateway/).

## Validation performed

- Strict Helm lint and template rendering passed for chart `0.11.22`, targeting Kubernetes `1.37.2`.
- The generated application configuration passed the official Authelia `4.39` JSON Schema. A negative check confirmed that the schema rejects `administration.enable_ui`.
- YAML duplicate-key checks, mounted Secret key/path checks, the private portal URL, and single-replica `Recreate` behavior passed. Helm renders a ServiceAccount, ConfigMap, Service, and Deployment, with no generated credentials or PVC.
- Actual secret values, the user database, PostgreSQL connectivity, runtime validation, Tailscale provisioning, and browser login/MFA remain to be verified during deployment. The local Docker daemon was unavailable, so the Authelia binary was not executed.
