# Epic 1: Golden Image Automation

## Overview

**Status:** Planning
**Priority:** High
**Epic Owner:** TBD
**Target Completion:** TBD

## Goal

Create a repeatable, automated pipeline for building the base operating system image with security hardening, drivers, and core infrastructure.

## Key Technologies

- **Packer** - Image building and automation
- **Ansible** - Configuration management and provisioning
- **Ubuntu 24.04 LTS** - Base operating system

## Scope

### In Scope

- Automated OS installation and configuration
- Security hardening implementation
- Driver installation and validation
- Core infrastructure setup
- Automated testing and validation
- Version control and artifact management
- CI/CD pipeline integration

### Out of Scope

- Application-specific configurations (handled in later epics)
- Runtime orchestration
- Production deployment procedures

## Success Criteria

1. Automated pipeline successfully builds golden image without manual intervention
2. Image passes all security compliance tests
3. All required drivers are installed and functional
4. Build process is reproducible and version-controlled
5. Build time is optimized (target: < 30 minutes)
6. Documentation is complete and tested

## Technical Requirements

### Infrastructure Requirements

- Build server/agent with sufficient resources
- Storage for image artifacts
- Network access for package downloads
- Access to hardware drivers repository

### Security Requirements

- CIS Ubuntu 24.04 LTS Benchmark compliance
- Hardened SSH configuration
- Firewall rules configured
- Automatic security updates enabled
- Audit logging configured
- Secure boot support

### Driver Requirements

- NVIDIA GPU drivers (if applicable)
- Network interface drivers
- Storage controller drivers
- Any specialized hardware drivers

## User Stories

### Story 1: Packer Template Creation
**As a** DevOps engineer
**I want** a Packer template that defines the golden image
**So that** I can build reproducible images

**Acceptance Criteria:**
- Packer template is created and version-controlled
- Template supports variable configuration
- Template includes provisioner hooks for Ansible

### Story 2: Ansible Playbook Development
**As a** DevOps engineer
**I want** Ansible playbooks for system configuration
**So that** the image is consistently configured

**Acceptance Criteria:**
- Playbooks are modular and role-based
- Playbooks handle security hardening
- Playbooks install required drivers
- Playbooks are idempotent

### Story 3: Security Hardening Implementation
**As a** security engineer
**I want** automated security hardening
**So that** images meet compliance requirements

**Acceptance Criteria:**
- CIS Benchmark controls are implemented
- Security scanning is automated
- Compliance reports are generated
- Vulnerabilities are addressed

### Story 4: Automated Testing
**As a** DevOps engineer
**I want** automated validation of built images
**So that** I can ensure image quality

**Acceptance Criteria:**
- Automated tests verify OS functionality
- Driver functionality is validated
- Security configuration is tested
- Test results are reported

### Story 5: CI/CD Pipeline Integration
**As a** DevOps engineer
**I want** the build process integrated into CI/CD
**So that** images are built automatically on changes

**Acceptance Criteria:**
- Pipeline is triggered on repository changes
- Build artifacts are versioned and stored
- Build status is reported
- Failed builds trigger notifications

## Task Breakdown

**Critical Note:** Approximately 70% of Epic 1 tasks can be completed on MacBook Pro before GPU hardware arrives. Tasks marked with ✅ are MacBook-friendly; tasks marked with ❌ require GPU hardware.

### Task Summary

| Task | Description | Effort | MacBook Friendly |
|------|-------------|--------|------------------|
| **Task 1.1** | Development Environment Setup | 2 hours | ✅ Yes |
| **Task 1.2** | Git Repository Setup | 1 hour | ✅ Yes |
| **Task 1.3** | Packer Template Creation | 4-6 hours | ✅ Yes |
| **Task 1.4** | Ansible Playbooks - Base System | 4 hours | ✅ Yes |
| **Task 1.5** | CIS Hardening Implementation | 6 hours | ✅ Yes |
| **Task 1.6** | Docker Installation | 3 hours | ✅ Yes |
| **Task 1.7** | Python & ML Tools | 3 hours | ✅ Yes |
| **Task 1.8** | NVIDIA Driver Installation | 4 hours | ❌ GPU Required |
| **Task 1.9** | NVIDIA Container Toolkit | 2 hours | ❌ GPU Required |
| **Task 1.10** | Integration Testing | 4-6 hours | ❌ GPU Required |

**Total Estimated Effort:** 30-40 hours (70% can start immediately on MacBook)

### Detailed Task Descriptions

#### Task 1.1: Development Environment Setup
**Effort:** 2 hours | **MacBook Friendly:** ✅ Yes

**Description:**
Set up local development environment for testing and iterating on Packer/Ansible configurations without requiring GPU hardware.

**Activities:**
- Install VirtualBox or UTM (for Apple Silicon Macs)
- Download Ubuntu 24.04 LTS ISO image
- Create test virtual machine with appropriate resources
- Verify VM can boot and install Ubuntu successfully
- Document environment setup steps

**Deliverables:**
- Working VM environment
- Setup documentation
- Screenshot/validation of successful Ubuntu boot

**Dependencies:**
- None (can start immediately)

---

#### Task 1.2: Git Repository Setup
**Effort:** 1 hour | **MacBook Friendly:** ✅ Yes

**Description:**
Create organized project structure with proper Git repository setup and folder hierarchy.

**Activities:**
- Initialize Git repository
- Create directory structure:
  - `/packer` - Packer templates and configurations
  - `/ansible` - Ansible playbooks, roles, and inventory
  - `/scripts` - Helper scripts and utilities
  - `/docs` - Documentation and diagrams
  - `/tests` - Test scripts and validation tools
- Create `.gitignore` for build artifacts
- Set up README.md with project overview
- Create initial branch protection rules (if applicable)

**Deliverables:**
- Organized repository structure
- README.md with project description
- `.gitignore` configured
- Initial commit pushed to remote

**Dependencies:**
- None

---

#### Task 1.3: Packer Template Creation
**Effort:** 4-6 hours | **MacBook Friendly:** ✅ Yes

**Description:**
Create Packer template for automated Ubuntu 24.04 LTS installation with preseed/cloud-init configuration.

**Activities:**
- Create base Packer HCL template
- Configure Ubuntu ISO source
- Write preseed configuration for automated installation
- Configure cloud-init for initial system setup
- Set up user accounts and SSH access
- Define variable files for customization
- Test build on VirtualBox/UTM
- Optimize build time and resource usage

**Deliverables:**
- `ubuntu-base.pkr.hcl` - Main Packer template
- `variables.pkrvars.hcl` - Variable definitions
- `preseed.cfg` or `user-data` - Automated installation config
- Build validation output

**Dependencies:**
- Task 1.1 (VM environment)
- Task 1.2 (Repository structure)

**Testing:**
- Successfully build base image on local VM
- Verify automated installation completes without errors
- Confirm SSH access to built image

---

#### Task 1.4: Ansible Playbooks - Base System
**Effort:** 4 hours | **MacBook Friendly:** ✅ Yes

**Description:**
Create Ansible playbooks for base system configuration including updates, package installation, and user management.

**Activities:**
- Set up Ansible role structure
- Create system update playbook
- Write package installation playbook (common utilities, build tools)
- Configure timezone, locale, and keyboard settings
- Set up user accounts and sudo permissions
- Configure system logging and monitoring basics
- Create idempotent playbook structure
- Test playbooks on VM

**Deliverables:**
- `site.yml` - Main playbook orchestrator
- `roles/base-system/` - Base system configuration role
- `roles/common-packages/` - Package installation role
- `roles/users/` - User management role
- Inventory file for local testing
- Role documentation

**Dependencies:**
- Task 1.3 (Base Packer template)

**Testing:**
- Run playbooks multiple times (idempotency check)
- Verify all packages installed correctly
- Confirm user accounts and permissions

---

#### Task 1.5: CIS Hardening Implementation
**Effort:** 6 hours | **MacBook Friendly:** ✅ Yes

**Description:**
Implement CIS Level 1 benchmark controls for Ubuntu 24.04 LTS through Ansible automation.

**Activities:**
- Review CIS Ubuntu 24.04 LTS Benchmark documentation
- Create Ansible role for CIS hardening
- Implement Level 1 Server controls:
  - Filesystem hardening (disable unused filesystems)
  - Configure software updates
  - Filesystem integrity checking
  - Secure boot settings
  - Process hardening
  - Mandatory access controls
  - Warning banners
  - Network parameter hardening
  - Firewall configuration (UFW)
  - Audit logging configuration (auditd)
  - SSH hardening
  - User account and environment controls
- Document any exceptions or deviations
- Create compliance validation script

**Deliverables:**
- `roles/cis-hardening/` - CIS hardening Ansible role
- Hardening documentation
- Compliance checklist
- OpenSCAP or custom validation script

**Dependencies:**
- Task 1.4 (Base system playbooks)

**Testing:**
- Run CIS benchmark scanner
- Verify hardening doesn't break system functionality
- Document compliance score

---

#### Task 1.6: Docker Installation
**Effort:** 3 hours | **MacBook Friendly:** ✅ Yes

**Description:**
Create Ansible playbook for Docker Engine, containerd, and docker-compose installation with proper configuration.

**Activities:**
- Create Docker installation Ansible role
- Add Docker GPG key and repository
- Install Docker Engine and containerd
- Install Docker Compose plugin
- Configure Docker daemon settings (logging, storage driver)
- Set up Docker user groups
- Configure Docker to start on boot
- Test Docker installation and basic functionality

**Deliverables:**
- `roles/docker/` - Docker installation role
- Docker daemon configuration file
- Docker installation validation script
- Documentation for Docker setup

**Dependencies:**
- Task 1.4 (Base system playbooks)

**Testing:**
- Run `docker run hello-world`
- Verify docker-compose functionality
- Confirm non-root user can run Docker commands

---

#### Task 1.7: Python & ML Tools Installation
**Effort:** 3 hours | **MacBook Friendly:** ✅ Yes

**Description:**
Install Python 3.10+, pip, virtualenv, and common ML libraries that don't require GPU.

**Activities:**
- Create Python/ML tools Ansible role
- Install Python 3.10+ from deadsnakes PPA (if needed)
- Install pip and setuptools
- Install virtualenv and virtualenvwrapper
- Install common ML libraries:
  - NumPy
  - Pandas
  - Scikit-learn
  - Matplotlib
  - Jupyter
- Configure Python environment variables
- Create default virtualenv
- Install development tools (ipython, pylint, black)

**Deliverables:**
- `roles/python-ml/` - Python and ML tools role
- Python environment configuration
- Requirements file for ML libraries
- Validation script for Python environment

**Dependencies:**
- Task 1.4 (Base system playbooks)
- Task 1.6 (Docker, for containerized ML workflows)

**Testing:**
- Verify Python version
- Test import of major ML libraries
- Run sample NumPy/Pandas script
- Test Jupyter notebook launch

---

#### Task 1.8: NVIDIA Driver Installation
**Effort:** 4 hours | **MacBook Friendly:** ❌ GPU Required

**Description:**
Install and configure NVIDIA GPU drivers and CUDA toolkit on actual GPU hardware.

**Activities:**
- Detect NVIDIA GPU model
- Add NVIDIA driver PPA/repository
- Install appropriate NVIDIA driver version
- Install CUDA toolkit
- Configure driver persistence
- Set up driver auto-loading on boot
- Verify driver installation
- Test CUDA functionality

**Deliverables:**
- `roles/nvidia-drivers/` - NVIDIA driver installation role
- Driver configuration files
- GPU detection and validation scripts
- Troubleshooting documentation

**Dependencies:**
- Task 1.4 (Base system playbooks)
- GPU hardware available

**Testing:**
- Run `nvidia-smi` command
- Verify CUDA installation with `nvcc --version`
- Run CUDA sample programs
- Test GPU under load

**Blockers:**
- Requires physical GPU hardware to test and validate

---

#### Task 1.9: NVIDIA Container Toolkit Installation
**Effort:** 2 hours | **MacBook Friendly:** ❌ GPU Required

**Description:**
Enable Docker GPU access via NVIDIA Container Toolkit for GPU-accelerated containers.

**Activities:**
- Install NVIDIA Container Toolkit
- Configure Docker daemon for GPU support
- Restart Docker service
- Test GPU access from containers
- Create sample GPU container for validation
- Document GPU container usage

**Deliverables:**
- `roles/nvidia-container-toolkit/` - Toolkit installation role
- Docker daemon configuration for GPU
- Sample GPU container test
- GPU container documentation

**Dependencies:**
- Task 1.6 (Docker installation)
- Task 1.8 (NVIDIA drivers)
- GPU hardware available

**Testing:**
- Run `docker run --gpus all nvidia/cuda:11.0-base nvidia-smi`
- Verify GPU visible from container
- Test PyTorch/TensorFlow GPU container

**Blockers:**
- Requires physical GPU hardware and NVIDIA drivers installed

---

#### Task 1.10: Integration Testing
**Effort:** 4-6 hours | **MacBook Friendly:** ❌ GPU Required

**Description:**
Build complete golden image on real GPU hardware and verify all components work together.

**Activities:**
- Build full golden image using Packer on GPU hardware
- Run comprehensive test suite:
  - OS functionality tests
  - Security compliance validation
  - Docker functionality
  - GPU driver and CUDA tests
  - Container GPU access tests
  - Python/ML library tests with GPU
  - Network and storage tests
- Document any issues found
- Performance benchmarking
- Create image artifact with versioning
- Generate test report

**Deliverables:**
- Complete golden image artifact
- Integration test suite
- Test results and compliance report
- Performance benchmarks
- Known issues documentation
- Image deployment guide

**Dependencies:**
- All previous tasks (1.1-1.9)
- GPU hardware available
- Complete test environment

**Testing:**
- Full system functionality validation
- Security scan with OpenSCAP or similar
- GPU workload testing
- Container orchestration testing

**Blockers:**
- Requires all previous tasks completed
- Requires GPU hardware for validation

---

### Phase-Based Execution Plan

#### Phase 1: Pre-GPU Development (Tasks 1.1-1.7)
**Duration:** 20-25 hours | **Status:** Can start immediately

These tasks establish the foundation and can be fully completed and tested on MacBook Pro using virtualization:

1. Development environment setup
2. Repository structure
3. Packer template (tested on VirtualBox/UTM)
4. Base system Ansible playbooks
5. Security hardening
6. Docker installation
7. Python/ML tools (CPU-only libraries)

**Outcome:** ~70% of epic complete, ready for GPU integration

#### Phase 2: GPU Integration (Tasks 1.8-1.10)
**Duration:** 10-12 hours | **Status:** Blocked until GPU hardware arrives

These tasks require physical GPU hardware:

1. NVIDIA driver installation and configuration
2. NVIDIA Container Toolkit setup
3. Full integration testing on GPU hardware

**Outcome:** Complete golden image with GPU support validated

### Progress Tracking

Use this checklist to track task completion:

- [ ] Task 1.1: Development Environment Setup
- [ ] Task 1.2: Git Repository Setup
- [ ] Task 1.3: Packer Template Creation
- [ ] Task 1.4: Ansible Playbooks - Base System
- [ ] Task 1.5: CIS Hardening Implementation
- [ ] Task 1.6: Docker Installation
- [ ] Task 1.7: Python & ML Tools Installation
- [ ] Task 1.8: NVIDIA Driver Installation (GPU required)
- [ ] Task 1.9: NVIDIA Container Toolkit (GPU required)
- [ ] Task 1.10: Integration Testing (GPU required)

## Architecture

### Build Pipeline Flow

```
Git Push → CI/CD Trigger → Packer Build → Ansible Provisioning → Testing → Artifact Storage
```

### Component Breakdown

1. **Packer Builder**
   - ISO source configuration
   - VM settings
   - Boot commands
   - Provisioner integration

2. **Ansible Provisioner**
   - System update playbook
   - Security hardening playbook
   - Driver installation playbook
   - Core infrastructure playbook

3. **Testing Framework**
   - InSpec/ServerSpec for compliance testing
   - Custom validation scripts
   - Integration tests

4. **Artifact Management**
   - Version tagging
   - Storage location
   - Metadata tracking

## Dependencies

- Access to Ubuntu 24.04 LTS ISO
- Ansible Galaxy roles (if using community roles)
- Driver packages and repositories
- Build infrastructure provisioned
- CI/CD platform configured

## Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Driver compatibility issues | High | Medium | Thorough testing, vendor validation |
| Security compliance gaps | High | Low | Regular audits, automated scanning |
| Build time exceeds target | Medium | Medium | Optimize Packer configuration, parallel builds |
| Infrastructure resource constraints | Medium | Low | Resource monitoring, capacity planning |

## Milestones

1. **M1: Packer Template Complete** (Week 1-2)
   - Basic Packer template operational
   - Ubuntu 24.04 LTS installs successfully

2. **M2: Ansible Playbooks Complete** (Week 2-3)
   - Core configuration playbooks written
   - Security hardening implemented
   - Drivers installed

3. **M3: Testing Framework Complete** (Week 3-4)
   - Automated tests written
   - Validation passing

4. **M4: CI/CD Integration Complete** (Week 4-5)
   - Pipeline operational
   - Automated builds working

5. **M5: Documentation and Handoff** (Week 5-6)
   - Documentation complete
   - Team training completed

## Deliverables

- [ ] Packer template files
- [ ] Ansible playbooks and roles
- [ ] Test suite
- [ ] CI/CD pipeline configuration
- [ ] Build and deployment documentation
- [ ] Security compliance report
- [ ] Runbook for troubleshooting

## Documentation Requirements

- Architecture decision records (ADRs)
- Build process documentation
- Configuration guide
- Troubleshooting guide
- Security hardening checklist
- Testing procedures

## Open Questions

1. What specific drivers are required for the target hardware?
2. What CI/CD platform will be used?
3. Where will image artifacts be stored?
4. What are the specific security compliance requirements?
5. What monitoring/logging should be included in the golden image?

## References

- [Packer Documentation](https://www.packer.io/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [Ubuntu 24.04 LTS Release Notes](https://wiki.ubuntu.com/NobleNumbat/ReleaseNotes)
- [CIS Ubuntu 24.04 LTS Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)

## Changelog

| Date | Author | Changes |
|------|--------|---------|
| 2025-10-29 | TBD | Initial document creation |
| 2025-10-29 | TBD | Added detailed task breakdown with MacBook compatibility indicators, effort estimates, and phase-based execution plan |
