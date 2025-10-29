# Architecture Decision Records (ADRs) - Epic 1A

This directory contains Architecture Decision Records for Epic 1A: Demo Box Operation.

## Quick Reference

| Decision | Choice | Rationale | Status |
|----------|--------|-----------|--------|
| **Packer Builder** | QEMU (dev) + Bare Metal (prod) | MacBook-friendly iteration, real GPU for final build | ✅ Accepted |
| **Ansible Execution** | Local (Packer provisioner) | Simpler, faster, no SSH overhead during build | ✅ Accepted |
| **Docker Runtime** | Docker Engine + containerd | Familiar tooling, easier NVIDIA integration | ✅ Accepted |
| **Python Environment** | System Python 3.12 | Simplest for demo box, sufficient for single-user | ✅ Accepted |
| **Monitoring** | Basic (htop/nvtop) | Lightweight, no infrastructure overhead | ✅ Accepted |
| **Security Scope** | Basic hardening only | Full CIS compliance deferred to Epic 1B | ✅ Accepted |

## Index

1. [Packer Builder Selection](#01-packer-builder)
2. [Ansible Execution Mode](#02-ansible-execution)
3. [Docker Runtime](#03-docker-runtime)
4. [Python Environment](#04-python-environment)
5. [Monitoring Approach](#05-monitoring)
6. [Security Hardening Scope](#06-security-scope)

---

## 01: Packer Builder

**Date:** 2025-10-29
**Status:** Accepted
**Deciders:** System Architect

### Context

Need to choose Packer builder for automated image creation. Must support:
- MacBook Pro development (no GPU)
- Final builds on GPU hardware
- Fast iteration during development

### Options

1. **QEMU Builder**
   - Pros: MacBook-friendly (hvf accelerator), fast iteration, cross-platform
   - Cons: GPU passthrough complex, not final target

2. **VirtualBox Builder**
   - Pros: MacBook-friendly, good documentation
   - Cons: No GPU passthrough, slower than QEMU

3. **Bare Metal Builder**
   - Pros: Real GPU access, accurate performance
   - Cons: Slower iteration, requires hardware

### Decision

**Use QEMU for Week 1 development (Layer 1), transition to bare metal for Weeks 2-3 (Layers 2-5).**

### Consequences

**Positive:**
- Week 1 work proceeds without GPU hardware
- Fast iteration on base system configuration
- Smooth transition to GPU hardware when available

**Negative:**
- Need to validate Layer 1 works on both QEMU and bare metal
- Slight overhead of maintaining two build paths initially

**Mitigation:**
- Test Layer 1 on both platforms before proceeding
- Use same Ansible playbooks for both (platform-agnostic)

---

## 02: Ansible Execution

**Date:** 2025-10-29
**Status:** Accepted
**Deciders:** System Architect

### Context

Choose how Ansible provisions the image during Packer build.

### Options

1. **Local Execution** (Packer Ansible provisioner, local mode)
   - Pros: Simpler, faster, no network overhead, works in chroot
   - Cons: Requires Ansible on build machine

2. **Remote Execution** (SSH-based)
   - Pros: Ansible can be anywhere
   - Cons: Requires SSH setup during build, network dependency

### Decision

**Use local execution via Packer Ansible provisioner.**

### Consequences

**Positive:**
- Simpler build pipeline
- Faster provisioning (no SSH overhead)
- Works in restricted environments

**Negative:**
- Ansible must be installed on build machine

**Mitigation:**
- Document Ansible installation in setup guide
- Use containerized build environment if needed

---

## 03: Docker Runtime

**Date:** 2025-10-29
**Status:** Accepted
**Deciders:** System Architect

### Context

Choose container runtime for GPU-accelerated workloads.

### Options

1. **Docker Engine (docker.io) + containerd**
   - Pros: Familiar tooling, better documentation, easier NVIDIA integration
   - Cons: Additional daemon overhead

2. **containerd only**
   - Pros: Lighter weight, Kubernetes-native
   - Cons: Less user-friendly, more complex NVIDIA setup

### Decision

**Use Docker Engine with containerd runtime.**

### Consequences

**Positive:**
- Well-documented NVIDIA Container Toolkit integration
- Familiar `docker` CLI for users
- Easier troubleshooting and debugging

**Negative:**
- Slightly more resource overhead than containerd-only

**Future Consideration:**
- Epic 1B may introduce containerd-only for Kubernetes integration

---

## 04: Python Environment

**Date:** 2025-10-29
**Status:** Accepted
**Deciders:** System Architect

### Context

Choose Python environment management strategy for AI frameworks.

### Options

1. **System Python 3.12** (Ubuntu 24.04 default)
   - Pros: Simplest setup, no environment management, fast installation
   - Cons: Single environment, potential package conflicts

2. **venv** (Python virtual environments)
   - Pros: Isolated environments, standard library
   - Cons: Requires activation, path management complexity

3. **conda** (Anaconda/Miniconda)
   - Pros: Best for ML workflows, comprehensive package management
   - Cons: Large install size, complexity overkill for demo

### Decision

**Use system Python 3.12 for Epic 1A.**

### Consequences

**Positive:**
- Simplest installation and configuration
- Fastest setup time
- Sufficient for single-user demo box

**Negative:**
- All frameworks share same Python environment
- Potential for package version conflicts

**Future Consideration:**
- Epic 1B may introduce venv for multi-user scenarios
- Enterprise deployments may prefer conda

---

## 05: Monitoring

**Date:** 2025-10-29
**Status:** Accepted
**Deciders:** System Architect

### Context

Choose monitoring solution for GPU and system health.

### Options

1. **Basic Tools** (htop, iotop, nvtop)
   - Pros: Lightweight, no infrastructure overhead, sufficient for demos
   - Cons: No historical data, no alerting

2. **Prometheus + Grafana**
   - Pros: Production-grade, historical metrics, beautiful dashboards
   - Cons: Complex setup, resource overhead

### Decision

**Use basic monitoring tools for Epic 1A.**

**Stack:**
- `htop` - CPU/RAM monitoring (TUI)
- `iotop` - Disk I/O monitoring (TUI)
- `nvtop` - GPU monitoring (TUI)
- `nvidia-smi` - GPU status (CLI)
- Custom `monitor.sh` script

### Consequences

**Positive:**
- Minimal resource overhead
- Fast installation
- Sufficient for customer demos
- Easy to use and understand

**Negative:**
- No historical metrics
- No remote monitoring
- No alerting capabilities

**Future Consideration:**
- Epic 1B will add Prometheus + Grafana for production monitoring

---

## 06: Security Hardening Scope

**Date:** 2025-10-29
**Status:** Accepted
**Deciders:** System Architect

### Context

Define security hardening scope for Epic 1A demo box.

### Options

1. **Basic Hardening Only**
   - SSH key-only authentication
   - UFW firewall
   - fail2ban
   - Automatic security updates

2. **Full CIS Level 1 Compliance**
   - All of basic hardening
   - SELinux/AppArmor
   - Full disk encryption (LUKS)
   - Audit logging (auditd)
   - Intrusion detection (AIDE)
   - Compliance scanning

### Decision

**Implement basic hardening only for Epic 1A. Defer full CIS compliance to Epic 1B.**

### Consequences

**Positive:**
- Faster development (Week 1 completes on schedule)
- Sufficient security for demo environment
- Foundation established for Epic 1B

**Negative:**
- Not production-ready from security perspective
- Demo box should not be deployed in sensitive environments

**Mitigation:**
- Clearly document security limitations
- Add warning in deployment guide
- Epic 1B timeline already includes full compliance

---

## ADR Process

### Creating New ADRs

When making a significant architectural decision:

1. Copy template (see `adr-template.md`)
2. Number sequentially (07, 08, etc.)
3. Fill in all sections (Context, Options, Decision, Consequences)
4. Commit to Git
5. Update this README index

### ADR Lifecycle

- **Proposed:** Under discussion
- **Accepted:** Decision made and implemented
- **Superseded:** Replaced by newer ADR (link to replacement)
- **Deprecated:** No longer relevant

### References

- [Architecture Overview](../00-architecture-overview.md)
- [Layer Architecture](../01-layer-architecture.md)
- [Build Pipeline](../02-build-pipeline.md)
- [Testing Strategy](../03-testing-strategy.md)
