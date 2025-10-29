# ADR-002: Use Packer + Ansible for Golden Image Pipeline

**Status:** Accepted
**Date:** 2025-10-29
**Decision Makers:** DevOps Lead, CTO
**Consulted:** Vault AI Golden Image Architect Agent, Engineering Team
**Informed:** Product Team, Customer Success Team

---

## Context

The Vault Cube product requires an automated, repeatable process for building golden images. The golden image must be deployable to bare metal systems in air-gapped (offline) environments and meet enterprise security standards.

**Requirements:**
1. **Automation:** Golden image builds must be fully automated (no manual steps)
2. **Repeatability:** Same inputs produce identical outputs
3. **Air-Gap Compatible:** Can build without internet access (using local package mirrors)
4. **Testability:** Can build and test images in VMs before deploying to hardware
5. **Version Control:** All configuration must be in Git
6. **CI/CD Integration:** Can integrate with GitHub Actions or GitLab CI
7. **Maintainability:** Team can understand and modify without deep expertise

**Constraints:**
- Team has limited DevOps experience (2-3 years average)
- Air-gapped deployment is a hard requirement (government/healthcare customers)
- Must support both VM (testing) and bare metal (production) targets
- Build time should be <45 minutes for rapid iteration

---

## Decision

**We will use Packer (by HashiCorp) for image building and Ansible for configuration management.**

**Toolchain:**
- **Packer 1.9+:** Automates OS installation and produces bootable images
- **Ansible 2.15+:** Configures system (packages, security, GPU drivers, ML frameworks)
- **cloud-init:** Initial system bootstrapping (users, SSH, network)
- **QEMU/KVM:** VM builder for testing (macOS: UTM or VirtualBox)

---

## Rationale

### Why Packer?

#### 1. Multi-Platform Support
**Packer supports multiple builders:**
| Builder | Use Case | Notes |
|---------|----------|-------|
| QEMU | VM testing | Primary development target |
| VirtualBox | macOS development | For developers on MacBooks |
| VMware | Enterprise testing | If customer uses VMware |
| Bare Metal | Production | Via PXE boot or direct disk write |

**Benefit:** Develop on VMs, deploy to bare metal with same codebase.

#### 2. Immutable Infrastructure Philosophy
- Packer creates immutable images (infrastructure as code)
- Changes require rebuild, not in-place modification
- Reduces "configuration drift" over time
- Aligns with modern DevOps practices

#### 3. Automation-First Design
- Designed for CI/CD pipelines
- JSON/HCL configuration (version control friendly)
- Supports parallel builds (test multiple configs simultaneously)
- No GUI, fully scriptable

#### 4. Air-Gap Compatible
```hcl
# Packer can use local ISO and package mirrors
source "qemu" "ubuntu-offline" {
  iso_url      = "file:///mnt/offline/ubuntu-24.04-server-amd64.iso"
  iso_checksum = "sha256:abc123..."

  # Use local APT mirror during build
  http_directory = "http"  # Serves preseed/cloud-init configs
}
```

#### 5. Mature Ecosystem
- HashiCorp product (same company as Terraform, Vault)
- 10+ years of development
- Large community, extensive documentation
- Plugins for specialized builders

### Why Ansible?

#### 1. Agentless Architecture
- Uses SSH (no agent to install)
- Perfect for golden image: no long-running daemons
- Lightweight footprint

#### 2. Idempotent Playbooks
```yaml
# Ansible runs can be repeated safely
- name: Ensure NVIDIA driver installed
  apt:
    name: nvidia-driver-550
    state: present  # Will not reinstall if already present
```

**Benefit:** Can run playbook multiple times during development without breaking system.

#### 3. Human-Readable YAML
```yaml
# Easy for non-programmers to understand
- name: Install Docker
  apt:
    name:
      - docker-ce
      - docker-ce-cli
      - containerd.io
    state: latest
```

**Benefit:** Low learning curve for team.

#### 4. Reusable Roles
- Ansible Galaxy has thousands of pre-built roles
- Can use community roles for common tasks (Docker, NVIDIA, CIS hardening)
- Reduces development time

**Example:**
```bash
# Install community roles
ansible-galaxy install geerlingguy.docker
ansible-galaxy install dev-sec.os-hardening
```

#### 5. Air-Gap Support
```yaml
# Ansible can use local package mirrors
- name: Configure local APT mirror
  copy:
    dest: /etc/apt/sources.list
    content: |
      deb [trusted=yes] http://apt.vaultcube.local noble main universe

- name: Install packages from local mirror
  apt:
    name: nvidia-driver-550
    state: present
  # Will fetch from local mirror, not internet
```

### Why Packer + Ansible Together?

#### Division of Responsibilities
| Tool | Responsibility |
|------|----------------|
| **Packer** | OS installation, partitioning, bootloader, initial user |
| **Ansible** | Packages, configuration, security, GPU drivers, ML frameworks |

**Benefit:** Clean separation of concerns, easier to debug.

#### Example Workflow:
```
1. Packer:
   - Download Ubuntu 24.04 ISO
   - Boot VM from ISO
   - Run automated installer (cloud-init)
   - Create user account, set SSH key
   - Partition disk, install bootloader
   - Reboot into installed system

2. Packer calls Ansible:
   - Ansible connects via SSH
   - Runs playbooks to configure system
   - Installs packages, drivers, frameworks
   - Hardens security
   - Cleans up temporary files

3. Packer finalizes:
   - Shuts down VM
   - Converts VM disk to desired format (.qcow2, .vmdk, .img)
   - Computes checksum
   - Stores artifact
```

---

## Consequences

### Positive Consequences

1. **Industry-Standard Tools**
   - Packer and Ansible are widely used (millions of users)
   - Extensive documentation and tutorials
   - Easy to hire engineers with experience
   - Reduced "bus factor" risk

2. **Fast Iteration**
   - Build image in VM (~20-30 minutes)
   - Test changes quickly
   - No need for physical hardware during development

3. **Version Control**
   - All configuration in Git
   - Track changes over time
   - Code review for infrastructure changes
   - Rollback to previous versions easily

4. **CI/CD Integration**
   ```yaml
   # .github/workflows/build-golden-image.yml
   name: Build Golden Image
   on:
     push:
       branches: [main]

   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3
         - name: Install Packer
           run: |
             curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
             sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
             sudo apt-get update && sudo apt-get install packer
         - name: Build Image
           run: packer build packer/ubuntu-24.04-demo-box.pkr.hcl
   ```

5. **Air-Gap Compatible**
   - Packer can use local ISO
   - Ansible can use local package mirrors
   - Entire build can run offline (after initial setup)

6. **Testability**
   - Build in VM, validate before deploying
   - Automated testing (InSpec, ServerSpec, Testinfra)
   - Catch issues before customer deployment

### Negative Consequences

1. **Learning Curve**
   - Team needs to learn Packer HCL syntax (~4-8 hours)
   - Team needs to learn Ansible playbooks (~8-16 hours)
   - **Mitigation:** Extensive documentation, pair programming, training

2. **Build Time**
   - Full build takes 20-30 minutes (vs 5 minutes for Docker image)
   - NVIDIA driver installation adds 10-15 minutes
   - **Mitigation:** Packer supports caching, can create base image + incremental builds

3. **Debugging Complexity**
   - If build fails, need to debug Packer + Ansible
   - VM headless builds harder to debug than GUI
   - **Mitigation:**
     - Packer `-debug` flag drops into shell
     - `PACKER_LOG=1` for verbose output
     - Can SSH into failed builds for inspection

4. **Requires Virtualization**
   - Development requires QEMU/KVM or VirtualBox
   - macOS developers need UTM or VirtualBox (slower than Linux KVM)
   - **Mitigation:** Provide cloud build servers with KVM for faster builds

### Neutral Consequences

1. **Ansible is slower than shell scripts**
   - Ansible has overhead (~2-3x slower than raw bash)
   - **Trade-off:** Slower but more maintainable and idempotent

2. **Packer produces large artifacts**
   - Golden images are 30-50GB (raw disk images)
   - Requires significant storage
   - **Mitigation:** Compress images, store in artifact repository

3. **Alternative tools exist**
   - Could use other tools (FAI, Cubic, etc.)
   - Packer + Ansible is one of many valid choices
   - **Justification:** Industry standard, mature, air-gap compatible

---

## Alternatives Considered

### Alternative 1: Cubic (Ubuntu Customization Kit)

**Pros:**
- Ubuntu-specific, well-integrated
- GUI makes it easy for beginners
- Can create live USB with custom packages

**Cons:**
- GUI-based (not CI/CD friendly)
- Not scriptable, hard to version control
- Manual process, not repeatable
- No air-gap support out-of-box

**Verdict:** **Rejected** - Not suitable for automated builds

---

### Alternative 2: FAI (Fully Automatic Installation)

**Pros:**
- Designed for large-scale deployments
- Very powerful, highly customizable
- Strong Debian/Ubuntu support

**Cons:**
- Steep learning curve (complex configuration)
- Less community support than Packer
- Primarily for PXE boot (network installs)
- Overkill for single-system golden image

**Verdict:** **Rejected** - Too complex for our use case

---

### Alternative 3: Docker + Dockerfile

**Pros:**
- Team already familiar with Docker
- Very fast builds (<5 minutes)
- Excellent caching
- Simple configuration

**Cons:**
- **CRITICAL:** Docker builds container images, not bootable OS images
- Cannot boot bare metal from Docker image
- Would need to convert to bootable disk image (complex)
- Designed for application containers, not OS images

**Verdict:** **Rejected** - Wrong tool for the job

---

### Alternative 4: Cloud-init Only (No Packer)

**Pros:**
- Simpler, fewer tools
- cloud-init is already used for initial setup
- Can configure system on first boot

**Cons:**
- No OS installation automation (still need to install Ubuntu manually)
- Limited provisioning capabilities (package installation slow on first boot)
- No pre-built images for testing
- Requires internet on first boot (breaks air-gap requirement)

**Verdict:** **Rejected** - Insufficient for golden image creation

---

### Alternative 5: Manual Installation + Sysprep Script

**Pros:**
- Complete control
- No new tools to learn
- Simple to understand

**Cons:**
- Not repeatable (human error)
- Not version controlled
- No CI/CD integration
- "Snowflake" systems (each build slightly different)
- Not scalable (manual work for each image)

**Verdict:** **Rejected** - Not suitable for production

---

### Alternative 6: Chef / Puppet

**Pros:**
- Mature configuration management tools
- Strong enterprise adoption

**Cons:**
- Require agents (daemons running on system)
- Heavier weight than Ansible
- Designed for fleet management, not golden image creation
- Steeper learning curve (Ruby DSL for Chef)

**Verdict:** **Rejected** - Overkill, agent-based model not ideal

---

## Implementation Plan

### Phase 1: Development Environment Setup (Week 1, Task 1a.1)
- [ ] Install Packer 1.9+ on development machines
- [ ] Install Ansible 2.15+ on development machines
- [ ] Install QEMU/KVM (Linux) or UTM (macOS)
- [ ] Validate Packer can build test VM

### Phase 2: Packer Template Creation (Week 1, Task 1a.3)
- [ ] Create base Packer template: `packer/ubuntu-24.04-demo-box.pkr.hcl`
- [ ] Configure Ubuntu autoinstall (cloud-init)
- [ ] Set up SSH access for Ansible
- [ ] Test automated Ubuntu installation

### Phase 3: Ansible Playbook Development (Week 1-2, Tasks 1a.4-1a.7)
- [ ] Create Ansible directory structure
- [ ] Develop base system playbook
- [ ] Develop security hardening playbook
- [ ] Develop Docker installation playbook
- [ ] Develop Python environment playbook

### Phase 4: GPU Integration (Week 2, Tasks 1a.8-1a.12)
- [ ] Develop NVIDIA driver installation playbook
- [ ] Develop NVIDIA Container Toolkit playbook
- [ ] Develop ML frameworks playbooks (PyTorch, TensorFlow, vLLM)

### Phase 5: Integration & Testing (Week 3, Tasks 1a.13-1a.17)
- [ ] Integrate all playbooks into master playbook
- [ ] Test end-to-end build
- [ ] Validate image on bare metal
- [ ] Create documentation

---

## Validation

### Success Criteria

1. **Automation:**
   - [ ] Single command builds complete image: `packer build packer/ubuntu-24.04-demo-box.pkr.hcl`
   - [ ] Build completes without manual intervention
   - [ ] Build time <45 minutes

2. **Repeatability:**
   - [ ] Same inputs produce identical checksums
   - [ ] Builds on different machines produce same result
   - [ ] Can rebuild image 6 months later with same Packer/Ansible versions

3. **Air-Gap Compatibility:**
   - [ ] Build succeeds using only local package mirrors
   - [ ] Zero network calls during build (except to local mirrors)

4. **Version Control:**
   - [ ] All Packer templates in Git
   - [ ] All Ansible playbooks in Git
   - [ ] Changes tracked with meaningful commit messages

5. **CI/CD Integration:**
   - [ ] GitHub Actions workflow builds image on commit
   - [ ] Build artifacts stored in artifact repository
   - [ ] Build failures reported to team

6. **Maintainability:**
   - [ ] Non-author can understand Packer template
   - [ ] Non-author can modify Ansible playbooks
   - [ ] Documentation enables new engineer to contribute

---

## Monitoring & Metrics

### Build Metrics to Track
- **Build Duration:** Target <45 minutes
- **Build Success Rate:** Target >95%
- **Image Size:** Target <50GB
- **Artifact Download Time:** Target <10 minutes (1Gbps network)

### Quality Metrics
- **Lines of Code:** Ansible playbooks (target: <2000 lines)
- **Test Coverage:** Percentage of playbooks with automated tests (target: >80%)
- **Documentation Coverage:** Percentage of roles documented (target: 100%)

---

## References

### External References
- [Packer Documentation](https://developer.hashicorp.com/packer/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [Ubuntu Autoinstall](https://ubuntu.com/server/docs/install/autoinstall)
- [Packer + Ansible Tutorial](https://developer.hashicorp.com/packer/tutorials/docker-get-started)

### Internal References
- Epic 1a Specification (docs/epic-1a-demo-box.md)
- ADR-001: Ubuntu 24.04 LTS Decision (docs/architectural-decision-records/ADR-001-ubuntu-24-04-lts.md)

---

## Decision Log

| Date | Action | Decision Maker | Status |
|------|--------|----------------|--------|
| 2025-10-29 | ADR-002 Created | DevOps Lead | Proposed |
| 2025-10-29 | CTO Approval | CTO | Accepted |

---

## Notes

**Why Not Other Tools:**

1. **systemd-nspawn / machinectl:** Container-based, not for bootable images
2. **live-build:** Debian-specific, complex, steep learning curve
3. **debootstrap + chroot:** Too low-level, requires extensive scripting
4. **Terraform:** Infrastructure provisioning, not image building
5. **SaltStack:** Similar to Ansible but less popular, smaller community

**Lessons Learned (to be updated):**
- [To be filled in during Epic 1a implementation]
- [Document any Packer gotchas]
- [Document Ansible best practices discovered]

**Recommended Training Resources:**
- HashiCorp Packer Tutorial (4 hours): https://learn.hashicorp.com/packer
- Ansible for DevOps Book (8 hours reading)
- Team pair programming sessions (2 hours/week)

---

**Document Version:** 1.0
**Last Updated:** 2025-10-29
**Next Review:** End of Epic 1a (update with lessons learned)
