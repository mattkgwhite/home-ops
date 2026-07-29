# ADR 0001: Use an external NAS

- **Status:** Proposed
- **Date:** 2026-07-29
- **Owners:** TODO
- **Supersedes:** None

## Context

Persistent services need storage independent of a Kubernetes node. The current
repository uses a Hetzner Storage Box through SMB CSI, while the target handbook
calls for an external NAS decision. Capacity, location, hardware, and recovery
requirements are not yet verified.

## Decision

Adopt an external NAS as a storage and local-backup target after its requirements
and bill of materials are approved. It must not become the only backup copy.

## Alternatives

- Keep only the Hetzner Storage Box: simple, but maintains provider dependence.
- Use node-local disks: fast, but couples data recovery to node survival.
- Use distributed cluster storage: resilient at scale, but too complex for the
  currently documented single-node cluster.

## Consequences

- Storage survives individual compute rebuilds.
- Hardware, power, patching, monitoring, and replacement become operator duties.
- NAS failure and ransomware remain shared failure modes without off-site copies.
- TODO: Select protocol, platform, capacity, redundancy, and encryption.
