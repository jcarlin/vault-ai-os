# Epic 1A Architecture Documentation

**Version:** 1.0
**Date:** 2025-10-29
**Status:** Active Design
**Architect:** System Architecture Designer

---

## Overview

This directory contains the complete implementation architecture for **Epic 1A: Demo Box Operation**, a functional AI workstation image demonstrating 4× RTX 5090 GPU capability for PyTorch, TensorFlow, and vLLM workloads.

---

## Quick Navigation

### Core Architecture Documents

1. **[Architecture Overview](00-architecture-overview.md)** - Start here
   - System context and constraints
   - 5-layer architecture design
   - Technology stack decisions
   - Security, testing, and performance strategies
   - Success metrics and risks

2. **[Layer Architecture](01-layer-architecture.md)** - Deep dive into each layer
   - Layer 1: Base System (Ubuntu 24.04, security, Docker, Python)
   - Layer 2: Driver Stack (NVIDIA drivers, CUDA, cuDNN)
   - Layer 3: GPU Runtime (NVIDIA Container Toolkit, Docker GPU)
   - Layer 4: AI Frameworks (PyTorch, TensorFlow, vLLM)
   - Layer 5: Validation & Monitoring (tests, monitoring tools)

3. **[Build Pipeline](02-build-pipeline.md)** - Automated build process
   - 5-stage pipeline (Pre-build → Packer → Ansible → Testing → Finalization)
   - Detailed provisioning phases
   - Caching and optimization strategies
   - Error handling and recovery

4. **[Testing Strategy](03-testing-strategy.md)** - Comprehensive testing
   - Testing pyramid (Unit → Integration → Validation → Performance → Stress)
   - Test cases and scripts
   - Performance benchmarks
   - 24-hour thermal validation

### Supporting Documents

5. **[Architecture Decision Records](decisions/)** - Key technical decisions
   - Packer builder selection (QEMU vs bare metal)
   - Ansible execution mode (local vs remote)
   - Docker runtime (Engine vs containerd)
   - Python environment (system vs venv vs conda)
   - Monitoring approach (basic vs comprehensive)
   - Security hardening scope

6. **[System Diagrams](diagrams/system-architecture.md)** - Visual architecture
   - Complete 5-layer system architecture
   - Build pipeline flow
   - GPU-accelerated training data flow
   - Testing pyramid
   - Security architecture

---

## Architecture Summary

### Design Principles

1. **Layered Design** - 5 distinct layers with clear interfaces
2. **Idempotency** - All provisioning steps can be re-run safely
3. **Testability** - Each layer independently validated
4. **Incrementality** - Build complexity progressively
5. **Documentation-First** - Architecture decisions recorded in memory

### System Layers

```
Layer 5: Validation & Monitoring
    ↓ (requires)
Layer 4: AI Frameworks (PyTorch, TensorFlow, vLLM)
    ↓ (requires)
Layer 3: GPU Runtime (NVIDIA Container Toolkit)
    ↓ (requires)
Layer 2: Driver Stack (NVIDIA drivers, CUDA, cuDNN)
    ↓ (requires)
Layer 1: Base System (Ubuntu 24.04, Docker, Python)
```

### Build Timeline

| Stage | Duration | Cached |
|-------|----------|--------|
| Pre-Build Validation | 2 min | 2 min |
| Packer Build | 15 min | 10 min |
| Ansible Provisioning | 17 min | 17 min |
| Testing & Validation | 30 min | 30 min |
| Image Finalization | 3 min | 3 min |
| **TOTAL** | **67 min** | **62 min** |

**Target:** <30 min for Packer + Ansible (Stages 2-3) ✅ **27 min cached**

### Technology Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| **OS** | Ubuntu 24.04 LTS | Long-term support, broad compatibility |
| **Packer Builder** | QEMU (dev) + Bare Metal (prod) | MacBook-friendly iteration, real GPU access |
| **Ansible** | Local execution | Simpler, faster, no SSH overhead |
| **Docker** | Engine + containerd | Familiar tooling, easier NVIDIA integration |
| **Python** | System 3.12 | Simplest for demo box |
| **Monitoring** | Basic (htop/nvtop) | Lightweight, sufficient for demos |
| **Security** | Basic hardening | SSH keys, firewall, fail2ban (full CIS in Epic 1B) |

---

## Key Decisions

### 1. Packer Builder: QEMU + Bare Metal

**Decision:** Use QEMU for Layer 1 development on MacBook, transition to bare metal for GPU layers (2-5).

**Impact:**
- ✅ Week 1 work proceeds without GPU hardware
- ✅ Fast iteration on base system
- ⚠️ Must validate Layer 1 on both platforms

### 2. Ansible Execution: Local Mode

**Decision:** Use Packer Ansible provisioner in local mode (no SSH).

**Impact:**
- ✅ Simpler build pipeline
- ✅ Faster provisioning (no network overhead)
- ⚠️ Ansible must be installed on build machine

### 3. Python Environment: System Python

**Decision:** Use system Python 3.12 (Ubuntu 24.04 default) for Epic 1A.

**Impact:**
- ✅ Simplest setup, fastest installation
- ⚠️ All frameworks share same environment
- 🔮 Epic 1B may introduce venv for multi-user

### 4. Monitoring: Basic Tools Only

**Decision:** Use htop, nvtop, nvidia-smi for Epic 1A. Defer Prometheus/Grafana to Epic 1B.

**Impact:**
- ✅ Minimal resource overhead
- ✅ Sufficient for customer demos
- 🔮 Epic 1B adds production monitoring

### 5. Security: Basic Hardening

**Decision:** Implement SSH hardening, firewall, fail2ban only. Full CIS compliance in Epic 1B.

**Impact:**
- ✅ Week 1 completes on schedule
- ✅ Sufficient security for demo environment
- ⚠️ **Not production-ready** (documented in setup guide)

---

## Testing Strategy

### Testing Pyramid

```
Stress Tests (1 test, 24 hours)
    ↓
Performance Benchmarks (4 tests, 20 min)
    ↓
Validation Tests (5 suites, 30 min)
    ↓
Integration Tests (10 tests, 15 min)
    ↓
Unit Tests (20+ tests, 5 min)
```

### Key Benchmarks

| Benchmark | Target | Rationale |
|-----------|--------|-----------|
| **PyTorch DDP Scaling** | >80% efficiency | Prove multi-GPU capability |
| **vLLM Throughput** | >10 tokens/sec | Prove LLM inference capability |
| **GPU Utilization** | >90% during training | Prove hardware utilization |
| **Build Time** | <30 min (Packer + Ansible) | Fast iteration |
| **Thermal Stability** | 24 hours without throttling | Prove reliability |

---

## Success Criteria

### Functional Requirements

- ✅ Golden image builds automatically via Packer
- ✅ All 4× RTX 5090 GPUs detected
- ✅ Docker runs GPU-accelerated containers
- ✅ PyTorch 2.x runs multi-GPU training
- ✅ TensorFlow 2.x runs multi-GPU training
- ✅ vLLM serves Llama-2-7B at >10 tokens/sec
- ✅ System completes 24-hour stress test

### Performance Requirements

- ✅ PyTorch DDP scaling >80%
- ✅ vLLM throughput >10 tokens/sec
- ✅ GPU utilization >90%
- ✅ Build time <30 minutes (Packer + Ansible)

### Security Requirements

- ✅ SSH key-based authentication only
- ✅ UFW firewall enabled
- ✅ Non-root user can run Docker and GPU containers
- ✅ No default passwords
- ✅ fail2ban protecting SSH

---

## Deliverables

### Code Deliverables

1. **Packer Template** - `packer/ubuntu-24.04-demo-box.pkr.hcl`
2. **Ansible Playbooks** - `ansible/playbooks/site.yml` + 10+ roles
3. **Validation Scripts** - `scripts/validate-gpus.sh`, `scripts/test-pytorch-ddp.py`, etc.
4. **Monitoring Script** - `scripts/monitor.sh`

### Image Deliverable

5. **Golden Image** - `vault-cube-demo-box-v1.0.qcow2`
   - Format: qcow2 or raw
   - Size: ~50GB
   - SHA256 checksum provided

### Documentation Deliverables

6. **Architecture Documentation** (this directory)
7. **Setup Guide** - `docs/demo-box-setup-guide.md`
8. **Known Issues** - `docs/demo-box-known-issues.md`
9. **Ansible Role Docs** - README.md in each role

---

## Risks & Mitigations

### Critical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **RTX 5090 Driver Compatibility** | Medium (40%) | High | Test multiple driver versions, have fallback |
| **GPU Hardware Delayed** | Medium (30%) | High | Pivot to Epic 1B prep if delayed |
| **Thermal Throttling** | High (60%) | Medium | Progressive stress testing, fan curve tuning |

### Medium Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Packer Preseed Complexity** | High (60%) | Low | Start with cloud-init, iterate |
| **CUDA Version Compatibility** | Medium (40%) | Medium | Validate compatibility, have CUDA 12.1 fallback |

---

## Implementation Roadmap

### Week 1: Foundation (MacBook-Friendly)

**Focus:** Layer 1 development without GPU hardware

**Tasks:**
- Development environment setup
- Git repository structure
- Packer template creation (QEMU builder)
- Ansible playbooks (common, users, security, docker, python)
- Unit tests for all roles

**Milestone:** Base Ubuntu image builds automatically

### Week 2: AI Runtime (GPU Hardware Required)

**Focus:** Layers 2-4 (drivers, runtime, frameworks)

**Tasks:**
- NVIDIA driver installation (Layer 2)
- NVIDIA Container Toolkit (Layer 3)
- PyTorch, TensorFlow, vLLM installation (Layer 4)
- Integration tests

**Milestone:** All AI frameworks installed, GPUs accessible

### Week 3: Validation & Documentation

**Focus:** Layer 5 and comprehensive testing

**Tasks:**
- Validation scripts
- Performance benchmarks
- 24-hour stress test
- Documentation

**Milestone:** Demo box operational, ready for customers

---

## Next Steps

### Immediate Actions

1. ✅ **Architecture design complete** (this document)
2. ⏭️ **Begin Week 1 implementation:**
   - Task 1a.1: Development environment setup
   - Task 1a.2: Git repository structure
   - Task 1a.3: Packer template creation
3. ⏭️ **Create detailed implementation plan** (sprint planning)

### Before Starting Implementation

- [ ] Confirm GPU hardware delivery date (Week 2)
- [ ] Procure Ubuntu 24.04 LTS ISO
- [ ] Set up development environment (Packer, Ansible, VM)
- [ ] Initialize Git repository

---

## Document Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-10-29 | 1.0 | Initial architecture design | System Architect |

---

## References

- [Epic 1A Requirements](../epic-1a-demo-box.md)
- [Epic 1 Overview](../epic-1-golden-image-automation.md)
- [Epic 1B Production Hardening](../epic-1b-production-hardening.md)
- [Packer Documentation](https://www.packer.io/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [NVIDIA CUDA Installation Guide](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)

---

**Questions or feedback?** Contact the System Architect or review the [Architecture Decision Records](decisions/README.md).
