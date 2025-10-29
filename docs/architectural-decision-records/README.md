# Architectural Decision Records (ADRs)

This directory contains Architectural Decision Records for the Vault Cube Golden Image project.

## What is an ADR?

An Architectural Decision Record (ADR) captures an important architectural decision made along with its context and consequences. It provides a historical record of why certain technical choices were made.

## ADR Format

Each ADR follows this structure:
- **Status:** Proposed | Accepted | Rejected | Superseded | Deprecated
- **Context:** The issue motivating this decision
- **Decision:** The change being proposed or made
- **Consequences:** The resulting context after applying the decision

## Active ADRs

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [ADR-001](./ADR-001-ubuntu-24-04-lts.md) | Use Ubuntu 24.04 LTS Instead of 22.04 LTS | Proposed | 2025-10-29 |
| [ADR-002](./ADR-002-packer-ansible.md) | Use Packer + Ansible for Golden Image Pipeline | Accepted | 2025-10-29 |
| [ADR-003](./ADR-003-cis-level-1.md) | Implement CIS Level 1 for MVP | Accepted | 2025-10-29 |
| [ADR-004](./ADR-004-apt-mirror.md) | Use APT Mirror for Air-Gap Deployment | Accepted | 2025-10-29 |
| [ADR-005](./ADR-005-prometheus-grafana.md) | Include Prometheus + Grafana in Golden Image | Proposed | 2025-10-29 |

## Creating a New ADR

1. Copy the template: `cp ADR-template.md ADR-XXX-title.md`
2. Fill in the sections
3. Submit for review via pull request
4. Update this README with the new ADR

## ADR Lifecycle

```
Proposed → Accepted → (Superseded/Deprecated)
       ↘ Rejected
```

- **Proposed:** Under review, not yet implemented
- **Accepted:** Approved and being implemented or already implemented
- **Rejected:** Reviewed and decided against
- **Superseded:** Replaced by a newer ADR
- **Deprecated:** No longer relevant but kept for historical record
