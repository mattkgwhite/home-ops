# ADR 0003: Standardise on UniFi networking

- **Status:** Proposed
- **Date:** 2026-07-29
- **Owners:** TODO
- **Supersedes:** None

## Context

The Kubernetes network is represented in code, but the physical LAN, VLANs,
firewall, wireless network, and management plane are not. A single network
platform can reduce operational fragmentation.

## Decision

Standardise future on-premises switching, gateway, and wireless management on
UniFi after required ports, PoE, throughput, high availability, and export or
backup capabilities are validated.

## Alternatives

- Mixed vendors: best-of-breed flexibility with more management surfaces.
- Open networking: greater control with a higher maintenance burden.
- ISP equipment: lowest cost but limited segmentation and observability.

## Consequences

- Centralises common network operations and configuration backups.
- Creates vendor and controller dependence.
- Advanced routing or automation needs may exceed product capabilities.
- TODO: Define VLANs, firewall policy, controller placement, and recovery.
