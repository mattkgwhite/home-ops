# Authelia research, deployment design, and documentation roadmap

Status: Draft for review  
Created: 2026-11-02

This document records the proposed plan from the Authelia research conversation. Saving this plan does not approve or execute the deployment or the wider documentation changes described below. Repository and cluster observations are a snapshot from 2026-11-02 and must be checked again before implementation.

## Summary

Authelia can provide a shared identity and MFA service, using different integrations for different consumers:

| Consumer | Recommended authentication |
| --- | --- |
| Applications supporting SSO | Native OpenID Connect (OIDC) |
| Browser applications without OIDC | Envoy Gateway external authorization |
| Kubernetes API and `kubectl` | Authelia OIDC, `kubelogin`, and Kubernetes RBAC |
| Private connectivity | Retain Tailscale alongside authentication |

These approaches are documented by Authelia for [Envoy Gateway](https://www.authelia.com/integration/kubernetes/envoy/gateway/) and [Kubernetes login](https://www.authelia.com/integration/openid-connect/clients/kubelogin/).

Browser authentication cannot cover every protocol or machine client. The research will distinguish access protection, application login, permissions, and service credentials. Proxy authentication only signs a user into the application itself when that application supports trusted identity headers.

The proposed work produces research documents and a future deployment runbook. Deployment and the wider documentation overhaul follow separately.

## 1. Authelia research documentation

Create four documents under `docs/research/authelia`:

- **README.md:** Feasibility, recommended architecture, comparison with Authentik and Tailscale, resource considerations, and dated sources.
- **integrations.md:** A service matrix covering active applications and clearly labelled deployment candidates. Record native OIDC, proxy authentication, trusted headers, MFA, API/client compatibility, and limitations.
- **deployment-plan.md:** Prerequisites, Argo CD configuration examples, rollout order, validation, and rollback.
- **operations.md:** User provisioning, MFA enrollment/recovery, credential rotation, backups, upgrades, troubleshooting, and emergency access.

Include diagrams showing private access, public access, and Kubernetes API authentication.

Separate repository configuration, live observations, historical notes, and proposed changes. The snapshot gathered on 2026-11-02 shows:

- Authelia and Authentik have no live Argo CD Applications.
- PostgreSQL and Tailscale are running.
- Envoy Gateway's controller exists, but no Gateway resources or Envoy-specific CRDs were found.
- The ApplicationSet explicitly selects manifests; adding a file alone does not activate deployment.
- Some live applications differ from repository configuration.

## 2. Deployment design to document

Use the choices established in the research conversation:

- One Authelia replica, existing PostgreSQL with a dedicated database/account, and in-memory sessions initially. Document session loss during restarts and Redis as a later scaling requirement.
- A small, explicitly managed user/group file supplied through External Secrets and 1Password. Support the administrator and invited users, with no public registration. Document manual account/password management for a Secret-mounted file.
- Mandatory MFA for human access: TOTP initially, with WebAuthn enrollment and recovery guidance.
- A stable HTTPS authentication hostname accessible to intended public users and the Kubernetes control plane. Use placeholders for deployment-specific values.

The runbook will specify the following sequence:

1. Verify database health, secret delivery, SMTP, DNS/TLS, gateway ownership, and required CRDs.
2. Pin and validate the official Helm chart and application image; follow the repository's existing Argo CD management pattern.
3. Bootstrap Authelia without protecting its own login endpoints behind its authorization middleware.
4. Protect one test application using fail-closed Envoy authorization, then document repeatable application onboarding.
5. Configure native OIDC for Argo CD and compatible applications, including group-to-role mappings.
6. Add Kubernetes API OIDC authentication and least-privilege RBAC while retaining independent emergency administration.

Address cookie-domain boundaries between custom domains and Tailscale hostnames, alternate routes that bypass protection, trusted-header spoofing, native/mobile clients, and webhook/API exceptions.

Use version-matched Talos configuration guidance rather than copying generic API-server flags. Include outage and bootstrap dependencies, especially avoiding dependence on an SSO-protected secret store for authentication recovery.

The repository currently configures the Tailscale API-server proxy in `noauth` mode. This provides connectivity while leaving authentication to Kubernetes; it is not anonymous Kubernetes API access. Compare retaining that model with Tailscale's authenticated proxy mode, while keeping Authelia OIDC as the proposed shared identity approach. See [Tailscale API-server proxy modes](https://tailscale.com/docs/kubernetes-operator/api-server-access).

Document the tradeoff of the selected minimal topology: one replica and in-memory sessions do not provide high availability. Authelia recommends stateless session storage for high-availability deployments. See [Authelia session providers](https://www.authelia.com/configuration/session/introduction/).

## 3. Documentation research and project backlog

Under `docs/research/documentation`, create an index and a documentation strategy covering:

- A proposed structure for architecture, setup, service guides, operations, decisions, research, and archives.
- An evidence-based inventory with ownership, dependencies, exposure, and verification dates.
- Public publishing options and a recommendation for hosting sanitized Markdown-based documentation on a custom domain.
- Private operational records stored outside the public repository.

Rebuild `docs/todo.md` as the single active backlog, preserving the archived list. Group work into identity, documentation, observability, applications, backups, networking, node management, and CI/CD. Give items priorities, dependencies, status, and completion criteria.

Carry forward existing tasks and evidenced application candidates without treating research candidates as approved deployments. Add unresolved deployment drift as verification work. Link the backlog and research from the root README.

The broader documentation overhaul, website implementation, and application deployments remain separate follow-up work after the Authelia research is reviewed.

## 4. Validation and boundaries

- Validate Markdown links, navigation, diagrams, and placeholder-only examples.
- Render Helm examples locally and validate configuration using the selected release, without deploying.
- Document acceptance tests for MFA, denied access, group permissions, OIDC callbacks, `kubectl`, token expiry, authentication outages, recovery, and private/public access.
- Reconcile conflicting upstream memory guidance against the selected release and password-hash settings; distinguish measured consumption from estimates. Relevant sources include the [Kubernetes deployment guidance](https://www.authelia.com/integration/kubernetes/introduction/) and [file authentication configuration](https://www.authelia.com/configuration/first-factor/file/).
- Exclude credentials, hashes, tokens, personal identities, infrastructure addresses, and raw configuration exports.
- Preserve existing draft changes and do not edit secrets or ignored files.
- Normalize the empty research directory names to the requested lowercase spelling when implementing the research documents. Retain `docs/archive` as the existing archive location.
- Do not deploy applications, alter live authentication, commit, push, or open a pull request as part of saving or reviewing this plan.
