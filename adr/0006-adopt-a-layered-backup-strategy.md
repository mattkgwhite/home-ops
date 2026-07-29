# ADR 0006: Adopt a layered backup strategy

- **Status:** Proposed
- **Date:** 2026-07-29
- **Owners:** TODO
- **Supersedes:** None

## Context

Git protects desired-state history but not persistent volumes, external service
state, credentials, or provider configuration. The repository identifies
backups as unfinished and does not contain tested restore evidence.

## Decision

Adopt a layered strategy with versioned Git configuration, local snapshots or
backups for rapid recovery, an encrypted off-site copy, and scheduled restore
tests. Define RPO and RTO per data class before implementation.

## Alternatives

- Provider snapshots only: convenient, but share provider and account failures.
- NAS only: fast local restore, but shares site and ransomware risks.
- Git only: restores declarations, not application data.

## Consequences

- Multiple failure domains reduce the chance of total data loss.
- Storage, egress, encryption keys, monitoring, retention, and testing add cost.
- A backup is not considered valid until a restore test succeeds.
- TODO: Select tooling, ownership, schedules, retention, and recovery targets.
