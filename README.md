# Vault Cube Golden Image

Automated golden image creation for Vault AI Systems Cube workstation platform.

## Project Overview

This repository contains Packer templates and Ansible playbooks for building production-ready golden images for the Vault Cube AI workstation featuring:
- 4× NVIDIA RTX 5090 GPUs
- AMD Threadripper PRO 7975WX (64-core)
- 256GB DDR5 ECC RAM
- Ubuntu 24.04 LTS

## Current Status

**Phase:** Epic 1a - Demo Box Operation (Foundation)
**Week:** 1 - Development Environment Setup

## Repository Structure

```
.
├── packer/              # Packer templates for image building
├── ansible/             # Ansible playbooks and roles
│   ├── playbooks/       # Main playbooks
│   ├── roles/           # Ansible roles
│   └── inventory/       # Inventory files
├── scripts/             # Validation and utility scripts
├── tests/               # Test scripts and validation
└── docs/                # Documentation
```

## Prerequisites

- Packer 1.9+
- Ansible 2.15+
- VirtualBox or UTM (for macOS testing)
- 8GB RAM minimum for VM testing
- Ubuntu 24.04 LTS ISO

## Quick Start

Coming soon in Week 1 as Packer templates are developed.

## Documentation

- [Epic 1a - Demo Box](docs/epic-1a-demo-box.md)
- [Epic 1b - Production Hardening](docs/epic-1b-production-hardening.md)
- [Architecture Overview](docs/ARCHITECTURE-SUMMARY.md)

## Development

See [CLAUDE.md](CLAUDE.md) for Claude Code configuration and SPARC workflow.

## License

Proprietary - Vault AI Systems
