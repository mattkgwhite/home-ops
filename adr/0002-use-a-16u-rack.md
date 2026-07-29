# ADR 0002: Use a 16U rack

- **Status:** Proposed
- **Date:** 2026-07-29
- **Owners:** TODO
- **Supersedes:** None

## Context

On-premises compute, networking, storage, power, and patching need a coherent
physical boundary. No verified rack inventory or environmental limits exist.

## Decision

Use a 16U rack as the target enclosure, subject to an approved elevation, depth,
load, power, cooling, noise, and access assessment before procurement.

## Alternatives

- Smaller wall cabinet: compact, but may constrain depth and future growth.
- Larger floor rack: more capacity, but higher space and handling cost.
- Shelves without a rack: low initial cost, but weaker cable and equipment
  management.

## Consequences

- Provides a defined capacity and labelling scheme.
- Requires reserved units for patching, airflow, power, and maintenance.
- Poor depth or load assumptions could make equipment incompatible.
- TODO: Confirm location and publish a rack elevation and power budget.
