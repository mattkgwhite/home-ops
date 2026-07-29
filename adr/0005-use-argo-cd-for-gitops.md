# ADR 0005: Use Argo CD for GitOps

- **Status:** Accepted
- **Date:** 2026-07-29
- **Owners:** TODO
- **Supersedes:** None

## Context

The repository contains active Argo CD Applications and an ApplicationSet that
discovers manifests. Flux content exists but is incomplete and documented as an
alternative experiment.

## Decision

Use Argo CD as the authoritative GitOps reconciler for the current cluster.
Keep non-deployed applications explicitly separated from active manifests.

## Alternatives

- Flux: strong GitOps primitives, but supporting two reconcilers adds ambiguity.
- CI push deployment: simpler reconciliation model but requires credentialed
  external writes and provides weaker continuous drift correction.
- Manual kubectl or Helm: useful for bootstrap only, not durable desired state.

## Consequences

- Git changes are continuously reconciled with visible application health.
- Argo CD becomes part of bootstrap and disaster recovery.
- Application ordering and CRD availability require deliberate management.
- Flux must not manage the same resources unless this decision is superseded.
