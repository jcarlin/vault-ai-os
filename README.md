# Vault Cube Golden Image

Automated golden image creation for Vault AI Systems Cube workstation platform.

## Project Overview

This repository contains Packer templates and Ansible playbooks for building production-ready golden images for the Vault Cube AI workstation featuring:
- 2× NVIDIA RTX 5090 FE (1 currently installed)
- AMD Threadripper PRO 7975WX (32-core/64-thread)
- 256GB DDR5 ECC RAM
- Ubuntu 24.04 LTS

## Current Status

**Phase:** Stage 2 — GPU stack validated, ready for Cube deployment

| Component | Status | Details |
|-----------|--------|---------|
| Base image (Packer + Ansible `site.yml`) | ✅ | Ubuntu 24.04, common/users/packages/networking/security |
| Docker + Python 3.12 | ✅ | Docker Engine + Python role |
| GPU stack (`gpu.yml`) | ✅ | Validated on GCP (Feb 21, 2026) |
| NVIDIA Driver 570 + CUDA 12.8 | ✅ | Open-source driver, kernel 6.13 |
| NVIDIA Container Toolkit | ✅ | Docker GPU passthrough working |
| PyTorch 2.10+cu128 | ✅ | GPU-accelerated via pip |
| TensorFlow (NGC container) | ✅ | `nvcr.io/nvidia/tensorflow:24.09-tf2-py3` |
| vLLM 0.13.0 (NGC container) | ✅ | `nvcr.io/nvidia/vllm-inference:26.01-py3` |
| Security hardening | ✅ | SSH, UFW, fail2ban, sysctl |
| All roles idempotent | ✅ | Run 3×, 0 changes on runs 2-3 |

**Next:** Deploy API gateway on the Cube, swap mock for real vLLM, end-to-end test.

## Repository Structure

```
.
├── packer/                      # Packer templates for image building
│   ├── ubuntu-24.04/                     # Ubuntu 24.04 templates (production)
│   │   ├── ubuntu-24.04-demo-box.pkr.hcl         # Local (VirtualBox)
│   │   ├── ubuntu-24.04-baremetal.pkr.hcl         # Bare metal (QEMU)
│   │   └── ubuntu-24.04-gcp.pkr.hcl              # GCP custom image
│   ├── http/                             # Cloud-init autoinstall files
│   └── output-*/                         # Build artifacts (.ova files)
├── ansible/                     # Ansible playbooks and roles
│   ├── playbooks/
│   │   ├── site.yml                      # Base system playbook
│   │   └── gpu.yml                       # GPU stack playbook
│   ├── roles/
│   │   ├── common/                       # Base system config
│   │   ├── users/                        # User management
│   │   ├── security/                     # SSH/firewall/fail2ban
│   │   ├── packages/                     # Package installation
│   │   ├── networking/                   # Network configuration
│   │   ├── docker/                       # Docker Engine
│   │   ├── python/                       # Python 3.12
│   │   ├── nvidia/                       # NVIDIA driver + CUDA
│   │   ├── nvidia-container-toolkit/     # Docker GPU access
│   │   ├── pytorch/                      # PyTorch with CUDA
│   │   ├── tensorflow/                   # TensorFlow (NGC container)
│   │   ├── vllm/                         # vLLM (NGC container)
│   │   └── monitoring-basic/             # nvidia-smi monitoring tools
│   ├── group_vars/
│   │   └── all.yml                       # Global variables
│   └── inventory/
│       └── production.yml                # Cube production inventory
├── scripts/                     # Validation and utility scripts
│   ├── setup-gcp.sh                      # GCP environment setup
│   ├── launch-gcp-gpu-test.sh            # Launch GPU test instance
│   ├── cleanup-gcp-resources.sh          # GCP cleanup
│   └── validate-gpus.sh                  # GPU validation
├── docs/                        # Documentation
│   ├── gpu-deploy-runbook.md             # Step-by-step GPU deployment
│   ├── hardware-specification-clarifications.md
│   └── architecture/                     # System architecture docs
└── tests/                       # Test scripts and validation
```

## Prerequisites

### Required Software

- **Packer:** 1.14.2+ ([Download](https://www.packer.io/downloads))
- **Ansible:** 2.19.3+ (Install: `brew install ansible` on macOS)
- **VirtualBox:** 7.0+ (for local builds) ([Download](https://www.virtualbox.org/))
- **gcloud CLI:** (for GCP builds)

### System Requirements

- **RAM:** 8GB minimum for VM testing (16GB recommended)
- **Disk:** 100GB free space for builds and artifacts
- **CPU:** 4 cores minimum (for VM allocation)

### Required Files (Local Builds)

- **Ubuntu 24.04 LTS ISO:** [Download](https://releases.ubuntu.com/24.04/)
- Or use GCP builds which don't require a local ISO

---

## Quick Start

### Build Base Image with Packer

```bash
cd packer/ubuntu-24.04

# Validate and build
packer validate ubuntu-24.04-demo-box.pkr.hcl
packer build ubuntu-24.04-demo-box.pkr.hcl
```

### Deploy GPU Stack on a Running System

```bash
# Get the code onto the target machine (git clone, scp, or USB)
cd ansible

# First: verify base system is clean
sudo ansible-playbook -i localhost, -c local playbooks/site.yml -vv

# Then: install GPU stack (will reboot after driver install)
sudo ansible-playbook -i localhost, -c local playbooks/gpu.yml -vv

# After reboot: re-run to complete remaining roles
sudo ansible-playbook -i localhost, -c local playbooks/gpu.yml -vv
```

See `docs/gpu-deploy-runbook.md` for the full step-by-step guide.

### GCP GPU Testing

```bash
./scripts/setup-gcp.sh              # Setup environment
./scripts/check-gcp-quotas.sh       # Verify GPU quotas
./scripts/launch-gcp-gpu-test.sh    # Launch test instance
./scripts/cleanup-gcp-resources.sh  # Cleanup
```

### Convenience Scripts (installed by gpu.yml)

```bash
vllm-serve <model_name>    # Launch vLLM NGC container serving a model
vllm-shell                 # Interactive shell in vLLM NGC container
tensorflow-shell           # Interactive shell in TensorFlow NGC container
```

---

## Default Credentials

- Username: `vaultadmin`
- Password: `vaultadmin`

---

## Development Workflow

**Fast Iteration (Ansible changes):**
1. Edit Ansible roles on your Mac
2. Boot VM with shared folder or SSH into Cube
3. Run `ansible-playbook` inside target
4. Test changes immediately
5. Repeat

**Full Build (final validation):**
1. Enable Ansible in Packer template
2. Run `packer build`
3. Test resulting image
4. Commit to git

**GPU Testing (GCP):**
1. `./scripts/launch-gcp-gpu-test.sh` creates a GPU instance
2. SSH in, clone repo, run `gpu.yml`
3. Validate with `nvidia-smi` and convenience scripts
4. `./scripts/cleanup-gcp-resources.sh` when done

### Best Practices

- Test Ansible manually first — faster than rebuilding Packer
- Use VirtualBox snapshots — save clean states before testing
- Run idempotency tests — playbook should work when run 3× times
- Check syntax before building — `packer validate` and `ansible-playbook --syntax-check`

---

## Documentation

- [GPU Deploy Runbook](docs/gpu-deploy-runbook.md) — Step-by-step GPU stack deployment
- [Hardware Spec Clarifications](docs/hardware-specification-clarifications.md) — Resolved hardware decisions
- [CLAUDE.md](CLAUDE.md) — Claude Code configuration and build commands

## License

Proprietary - Vault AI Systems

---

**Last Updated:** 2026-02-21
