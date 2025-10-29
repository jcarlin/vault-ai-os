# ADR-001: Use Ubuntu 24.04 LTS Instead of 22.04 LTS

**Status:** Proposed (Requires CTO Approval)
**Date:** 2025-10-29
**Decision Makers:** CTO, DevOps Lead, Product Lead
**Consulted:** Vault AI Golden Image Architect Agent
**Informed:** Engineering Team, Customer Success Team

---

## Context

The Vault Cube product requires a Linux distribution as the base operating system for the golden image. The current Product Blueprint v3.0 specifies Ubuntu 22.04 LTS, but the Production Spec and hardware requirements suggest Ubuntu 24.04 LTS may be more appropriate.

**Key Factors:**
- Hardware platform features cutting-edge components (RTX 5090 GPUs, PCIe 5.0, WRX90 chipset)
- NVIDIA RTX 5090 launched Q1 2025 - very new hardware
- Ubuntu 24.04 LTS was released April 2024 with kernel 6.8
- Ubuntu 22.04 LTS was released April 2022 with kernel 5.15 (HWE available)
- Product targets enterprise customers requiring long-term support

**Conflicting Specifications:**
- Product Blueprint v3.0: Ubuntu 22.04 LTS
- Production Spec (CLAUDE.md): Ubuntu 24.04 LTS
- Current Epic 1 documentation: Unspecified

---

## Decision

**We propose to standardize on Ubuntu 24.04 LTS (Noble Numbat) as the base operating system for the Vault Cube golden image.**

---

## Rationale

### Technical Requirements Favor 24.04 LTS

#### 1. Hardware Compatibility
**RTX 5090 GPU Support:**
- NVIDIA driver 550+ officially supports Ubuntu 24.04 LTS
- RTX 5090 is Blackwell architecture (launched Q1 2025)
- Ubuntu 22.04 LTS (kernel 5.15) lacks native support for newest GPUs
- While HWE (Hardware Enablement) kernel can backport support, it adds complexity

**PCIe 5.0 Support:**
- Ubuntu 24.04 kernel 6.8 has native PCIe 5.0 support
- Ubuntu 22.04 requires HWE kernel 6.5+ for PCIe 5.0
- WRX90 chipset (AMD platform) is better supported in newer kernels

**AMD Threadripper PRO 7975WX:**
- Zen 4 architecture launched 2023
- Better CPU scheduling and power management in kernel 6.8
- Ubuntu 24.04 has optimized AMD drivers

#### 2. NVIDIA Driver Ecosystem
**Driver Version Compatibility:**
| Component | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS | Winner |
|-----------|------------------|------------------|---------|
| NVIDIA Driver 550+ | ⚠️ Unofficial | ✅ Official | 24.04 |
| CUDA 12.4+ | ✅ Supported | ✅ Supported | Tie |
| cuDNN 9.x | ✅ Supported | ✅ Supported | Tie |
| RTX 5090 | ⚠️ Via HWE | ✅ Native | 24.04 |

**Driver Support Timeline:**
- NVIDIA typically optimizes drivers for latest Ubuntu LTS first
- RTX 5090 drivers (550+) released with Ubuntu 24.04 in mind
- Bug fixes and performance improvements land in 24.04 first

#### 3. Long-Term Support Lifecycle
**Support Duration:**
- Ubuntu 22.04 LTS: Supported until April 2027 (2 years remaining)
- Ubuntu 24.04 LTS: Supported until April 2029 (4 years remaining)

**Impact:**
- Products shipping in 2026 would only have 1 year of 22.04 support remaining
- 24.04 provides 2x longer support window
- Reduces forced upgrades for customers

#### 4. ML Framework Compatibility
**PyTorch 2.x:**
- Official PyTorch binaries built for Ubuntu 24.04
- CUDA 12.4 wheels tested on Ubuntu 24.04
- Better compatibility with kernel 6.8

**TensorFlow 2.x:**
- TensorFlow 2.16+ optimized for Ubuntu 24.04
- GPU performance improvements on newer kernels

**vLLM:**
- vLLM actively developed and tested on Ubuntu 24.04
- Dependency stack (transformers, accelerate) assumes modern Ubuntu

---

## Consequences

### Positive Consequences

1. **Native Hardware Support**
   - RTX 5090 GPUs work out-of-the-box without HWE kernel complexity
   - PCIe 5.0 functionality without backports
   - Better AMD CPU scheduling and power management

2. **Longer Support Timeline**
   - Products ship with 4 years of Ubuntu support (vs 2 years)
   - Reduces customer upgrade burden
   - Aligns with enterprise procurement cycles (3-5 years)

3. **Official NVIDIA Support**
   - Driver 550+ officially targets Ubuntu 24.04
   - Faster bug fixes and security patches
   - Better documentation and community support

4. **Modern Toolchain**
   - GCC 13 (vs GCC 11 in 22.04)
   - Python 3.12 available (vs 3.10 in 22.04)
   - systemd 255 with better container support
   - Newer OpenSSL, glibc, and system libraries

5. **Future-Proofing**
   - Next-gen hardware (RTX 6000 series) will likely require 24.04+
   - Kernel 6.8+ required for many upcoming hardware features
   - Easier migration path to Ubuntu 26.04 LTS in future

### Negative Consequences

1. **Newer LTS = Potential Bugs**
   - Ubuntu 24.04 released ~6 months ago (April 2024)
   - May have undiscovered bugs vs battle-tested 22.04 (2+ years in field)
   - **Mitigation:** 24.04.1 point release (July 2024) addressed early issues

2. **Enterprise Software Compatibility**
   - Some enterprise software vendors lag on Ubuntu LTS certification
   - Customers may require specific 22.04 for compliance
   - **Mitigation:** Most AI/ML software already supports 24.04

3. **Team Documentation Update**
   - Existing internal documentation references 22.04
   - Training materials need update
   - **Mitigation:** Low effort (~2-4 hours documentation work)

4. **Potential Customer Resistance**
   - Conservative enterprises may prefer older, proven LTS
   - "If it ain't broke, don't fix it" mentality
   - **Mitigation:** Position as "enterprise-ready" not "bleeding edge"

### Neutral Consequences

1. **CIS Benchmark Availability**
   - CIS Benchmark for Ubuntu 24.04 LTS is available (released mid-2024)
   - Migration effort if decision delayed: Low
   - Both versions have Level 1 and Level 2 benchmarks

2. **APT Mirror Size**
   - Ubuntu 24.04 mirror ~70GB (selective) vs ~450GB (full)
   - Same storage requirements as 22.04
   - Air-gap deployment equally complex

3. **Testing Effort**
   - Both versions require comprehensive testing
   - 24.04 may surface more hardware-specific issues early
   - Better to find issues now than post-customer deployment

---

## Alternatives Considered

### Alternative 1: Ubuntu 22.04 LTS (Current Blueprint)

**Pros:**
- More battle-tested (2+ years in production worldwide)
- Wider enterprise software support/certification
- Team already familiar with 22.04

**Cons:**
- Requires HWE kernel for RTX 5090 support (complexity)
- HWE kernel support ends before 22.04 LTS (creates gap)
- Only 2 years remaining support
- PCIe 5.0 support less mature
- Suboptimal for latest hardware

**Verdict:** **Rejected** - Hardware requirements dictate newer kernel

---

### Alternative 2: Ubuntu 22.04 LTS + HWE Kernel

**Pros:**
- Base system stability of 22.04
- Newer kernel (6.5+) for hardware support
- Gradual transition path

**Cons:**
- Complexity: Managing two kernel streams
- HWE kernel support ends in 2026 (before 22.04 LTS support ends in 2027)
- Creates 1-year gap where customers must upgrade kernel but OS still supported
- NVIDIA driver testing primarily on non-HWE kernels
- Added maintenance burden

**Verdict:** **Rejected** - Adds complexity without significant benefit

---

### Alternative 3: Ubuntu 23.10 (Non-LTS)

**Pros:**
- Latest kernel and packages
- Excellent hardware support

**Cons:**
- Support ends after 9 months (July 2024 - April 2024)
- Absolutely unsuitable for enterprise product
- No LTS upgrade path
- Forces customers to upgrade annually

**Verdict:** **Rejected** - Not enterprise-ready

---

### Alternative 4: RHEL 9 / Rocky Linux 9

**Pros:**
- 10-year support lifecycle
- Strong enterprise pedigree
- CentOS/RHEL familiar to many enterprises

**Cons:**
- NVIDIA driver support weaker than Ubuntu
- Smaller AI/ML ecosystem (less PyTorch/TensorFlow documentation)
- Different package management (dnf vs apt)
- Team lacks RHEL expertise
- Vault Cube positioning is "AI/ML workstation" not "enterprise server"

**Verdict:** **Rejected** - Ubuntu ecosystem better for AI/ML

---

### Alternative 5: Defer Decision, Support Both

**Pros:**
- Customer choice
- Hedges risk

**Cons:**
- 2x testing burden (every feature tested on both)
- 2x documentation burden
- 2x air-gap repository maintenance
- Split customer base complicates support
- Increases time-to-market

**Verdict:** **Rejected** - Operational complexity outweighs benefits

---

## Implementation Plan

### Phase 1: Decision Approval (Week 0)
- [ ] CTO reviews and approves ADR-001
- [ ] Product Lead confirms customer requirements alignment
- [ ] DevOps Lead confirms implementation feasibility

### Phase 2: Documentation Update (Week 1)
- [ ] Update Product Blueprint to specify Ubuntu 24.04 LTS
- [ ] Update Epic 1a/1b documentation
- [ ] Update CLAUDE.md
- [ ] Notify engineering team

### Phase 3: Packer Template Development (Week 1-2)
- [ ] Create Packer template for Ubuntu 24.04 LTS
- [ ] Test automated installation
- [ ] Validate cloud-init configuration

### Phase 4: Validation (Week 2-3)
- [ ] Test NVIDIA driver 550+ installation
- [ ] Verify RTX 5090 detection (when hardware available)
- [ ] Validate PyTorch, TensorFlow, vLLM installation
- [ ] Run CIS Benchmark Level 1 compliance scan

### Phase 5: Contingency Planning (Week 2)
- [ ] Document fallback to 22.04 + HWE if critical issues found
- [ ] Create decision criteria for fallback activation

---

## Validation

### Success Criteria
1. **Hardware Compatibility:**
   - [ ] All 4× RTX 5090 GPUs detected by nvidia-smi
   - [ ] NVIDIA driver 550+ installs without errors
   - [ ] PCIe 5.0 x16 link confirmed

2. **Software Compatibility:**
   - [ ] PyTorch 2.x installs and detects GPUs
   - [ ] TensorFlow 2.x installs and detects GPUs
   - [ ] vLLM installs and runs inference

3. **Security & Compliance:**
   - [ ] CIS Benchmark Level 1 scan achieves >90% compliance
   - [ ] OpenSCAP scans pass
   - [ ] No critical security vulnerabilities

4. **Performance:**
   - [ ] PyTorch DDP scaling >80% (4-GPU vs 1-GPU)
   - [ ] vLLM throughput >10 tokens/sec (Llama-2-7B)
   - [ ] No performance regression vs 22.04 (if tested)

### Rollback Criteria
If any of the following occur, revert to Ubuntu 22.04 LTS + HWE:
1. RTX 5090 drivers fail to install or GPUs not detected
2. Critical security vulnerabilities in 24.04 with no patch available
3. CIS compliance cannot achieve >80% due to 24.04-specific issues
4. Major customer explicitly requires 22.04 for compliance reasons

---

## References

### External References
- [Ubuntu 24.04 LTS Release Notes](https://wiki.ubuntu.com/NobleNumbat/ReleaseNotes)
- [NVIDIA Driver 550 Release Notes](https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-550/index.html)
- [Ubuntu LTS Hardware Enablement](https://ubuntu.com/about/release-cycle)
- [CIS Benchmark for Ubuntu 24.04 LTS](https://www.cisecurity.org/benchmark/ubuntu_linux)

### Internal References
- Product Blueprint v3.0 (docs/Vault_AI_Product_Blueprint_v3.0.docx)
- Production Spec (docs/Vault Cube Production Spec.pdf)
- CLAUDE.md (cube-golden-image/CLAUDE.md)
- Epic 1a Specification (docs/epic-1a-demo-box.md)
- Epic 1b Specification (docs/epic-1b-production-hardening.md)

---

## Decision Log

| Date | Action | Decision Maker | Status |
|------|--------|----------------|--------|
| 2025-10-29 | ADR-001 Created | DevOps Lead | Proposed |
| TBD | CTO Review | CTO | Pending |
| TBD | Product Review | Product Lead | Pending |
| TBD | Final Approval | CTO | Pending |

---

## Notes

**Important Considerations:**

1. **This decision affects Epic 1a start date:**
   - If approved: Proceed with Ubuntu 24.04 in Week 1
   - If delayed: Use Ubuntu 22.04 temporarily, migrate later
   - If rejected: Update all documentation to specify 22.04 + HWE

2. **Customer communication:**
   - If customers ask why not 22.04, position as "optimized for latest GPU hardware"
   - Emphasize 4-year vs 2-year support benefit
   - Highlight official NVIDIA driver support

3. **Fallback strategy:**
   - Keep 22.04 + HWE option available through Week 3
   - If RTX 5090 drivers prove problematic, fallback is tested
   - Document fallback procedure in Epic 1a

**Recommendation:** Approve Ubuntu 24.04 LTS decision before Epic 1a kickoff to avoid rework.

---

**Document Version:** 1.0
**Last Updated:** 2025-10-29
**Next Review:** After Epic 1a Week 2 (when GPU hardware arrives)
