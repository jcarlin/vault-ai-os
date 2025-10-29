# Hardware Specification Clarifications - Vault Cube

**Date:** 2025-10-29
**Status:** REQUIRES DECISION
**Priority:** CRITICAL (Blocks Epic 1a)

---

## Problem Statement

Conflicting hardware specifications exist across Vault Cube documentation. These conflicts must be resolved before Epic 1a begins to ensure proper driver installation, thermal design, and power planning.

---

## Specification Conflicts

### Conflict 1: GPU Configuration

| Source Document | GPU Specification | VRAM Total | Power Draw |
|----------------|-------------------|------------|------------|
| **Production Spec (PDF)** | 4× NVIDIA RTX 5090 FE | 128GB (32GB × 4) | ~2,400W |
| **Product Blueprint v3.0** | 2× NVIDIA RTX 4090 | 48GB (24GB × 2) | ~900W |
| **CLAUDE.md** | 4× NVIDIA RTX 5090 | 128GB | ~2,400W |

**Impact:**
- **Driver Requirements:** RTX 5090 requires driver 550+, RTX 4090 works with 525+
- **Power:** 2,400W vs 900W = 1,500W difference (PSU sizing)
- **Thermal:** 2,400W vs 900W = massive cooling difference
- **Cost:** 4× RTX 5090 ≈ $10,000 vs 2× RTX 4090 ≈ $3,200
- **ML Performance:** 4× 5090 provides 2.67x VRAM for larger models
- **Epic 1a Testing:** Determines which GPUs to procure for testing

**Recommendation:** **Use Production Spec: 4× RTX 5090 FE**
- Aligns with "high-performance AI workstation" positioning
- CLAUDE.md and Production Spec agree (2 out of 3 sources)
- Product Blueprint may be outdated (predates RTX 5090 launch)

---

### Conflict 2: System Memory

| Source Document | RAM Specification | Notes |
|----------------|-------------------|-------|
| **Production Spec (PDF)** | 256GB DDR5-6000 ECC RDIMM | Kingston Server Premier |
| **Product Blueprint v3.0** | 128GB+ DDR5 | No specific speed/type |
| **CLAUDE.md** | 256GB DDR5-6000 ECC | Matches Production Spec |

**Impact:**
- **vLLM Performance:** 256GB enables larger KV cache (more concurrent users)
- **Multi-Model Serving:** 256GB allows 2-3 models loaded simultaneously
- **Cost:** 256GB ≈ $1,600 vs 128GB ≈ $800
- **ECC vs Non-ECC:** ECC required for enterprise reliability

**Recommendation:** **Use Production Spec: 256GB DDR5-6000 ECC RDIMM**
- Matches Production Spec and CLAUDE.md
- ECC provides data integrity for AI workloads
- 256GB is becoming standard for LLM serving (not excessive)

---

### Conflict 3: Ubuntu Version

| Source Document | Ubuntu Version | Kernel | Support Until |
|----------------|----------------|--------|---------------|
| **Production Spec / CLAUDE.md** | Ubuntu 24.04 LTS | 6.8 | April 2029 |
| **Product Blueprint v3.0** | Ubuntu 22.04 LTS | 5.15 (or 6.5 HWE) | April 2027 |

**Impact:**
- **RTX 5090 Support:** 24.04 has native support, 22.04 requires HWE kernel
- **PCIe 5.0:** 24.04 kernel 6.8 has better PCIe 5.0 support
- **Support Timeline:** 24.04 supported 2 years longer
- **NVIDIA Drivers:** Driver 550+ officially targets 24.04

**Recommendation:** **Use Ubuntu 24.04 LTS (see ADR-001)**
- Better hardware compatibility for RTX 5090 and PCIe 5.0
- Longer support window (4 years vs 2 years remaining)
- Official NVIDIA driver support

---

### Conflict 4: Storage Configuration

| Source Document | Storage Specification | Notes |
|----------------|----------------------|-------|
| **Production Spec (PDF)** | 2× Samsung **9100 Pro** 4TB PCIe 5.0 | Likely typo |
| **CLAUDE.md** | 2× Samsung 9100 Pro 8TB total | References Production Spec |

**Issue:** Samsung "9100 Pro" does not exist. Possible models:
- **Samsung 990 Pro:** PCIe 4.0, consumer NVMe (most likely intended)
- **Samsung PM9A1:** PCIe 4.0, enterprise/OEM NVMe
- **Future Samsung PCIe 5.0 NVMe:** Not yet released (vaporware)

**Impact:**
- **Performance:** PCIe 4.0 (7,450 MB/s) vs PCIe 5.0 (14,000 MB/s theoretical)
- **Model Loading:** 7GB/s vs 14GB/s affects LLM loading time
- **Procurement:** Cannot purchase "9100 Pro" - must clarify

**Recommendation:** **Use Samsung 990 Pro 4TB (PCIe 4.0)** for now
- Widely available, proven reliability
- Upgrade path to PCIe 5.0 when available (future epic)
- 7,450 MB/s read sufficient for ML workloads

---

## Decision Matrix

| Specification | Production Spec | Product Blueprint | Recommended Choice | Rationale |
|--------------|----------------|-------------------|-------------------|-----------|
| **GPUs** | 4× RTX 5090 | 2× RTX 4090 | **4× RTX 5090** | Matches 2/3 sources, aligns with positioning |
| **RAM** | 256GB ECC | 128GB+ | **256GB ECC** | Enterprise reliability, better performance |
| **Ubuntu** | 24.04 LTS | 22.04 LTS | **24.04 LTS** | Hardware compatibility (ADR-001) |
| **Storage** | "9100 Pro" (typo) | Not specified | **990 Pro 4TB** | Closest available model |

---

## Questions Requiring CTO/Product Decision

### Question 1: GPU Configuration (CRITICAL)
**Which GPU configuration is correct for the Vault Cube product?**

**Option A:** 4× NVIDIA RTX 5090 Founders Edition (~$10,000)
- **Pros:** Cutting-edge performance, 128GB VRAM, flagship positioning
- **Cons:** Higher cost, power, thermal requirements
- **Power:** 2,400W GPUs + 350W CPU = 2,750W (fits 3000W PSU with 50W margin)
- **Thermal:** 10,000 BTU/h heat dissipation required

**Option B:** 2× NVIDIA RTX 4090 (~$3,200)
- **Pros:** Lower cost, easier thermal management, proven hardware
- **Cons:** Limited VRAM (48GB), mid-tier positioning
- **Power:** 900W GPUs + 350W CPU = 1,250W (ample PSU headroom)
- **Thermal:** ~4,300 BTU/h heat dissipation

**Recommendation:** **Option A (4× RTX 5090)** if positioning as "flagship AI workstation"

**Impact on Epic 1a:**
- Determines which GPU drivers to test (driver 550+ vs 525+)
- Affects thermal testing requirements
- Determines test hardware to procure

---

### Question 2: Memory Configuration (HIGH PRIORITY)
**Confirm: 256GB DDR5-6000 ECC RDIMM is correct?**

**Recommended:** YES - Use 256GB DDR5-6000 ECC

**Justification:**
- Required for vLLM serving with large KV cache
- ECC provides enterprise-grade reliability
- Allows multi-model serving (2-3 models simultaneously)
- DDR5-6000 is sweet spot for price/performance

---

### Question 3: Storage Model Clarification (MEDIUM PRIORITY)
**What is the correct Samsung NVMe model?**

**Recommendation:** Samsung 990 Pro 4TB (×2)
- PCIe 4.0 x4, 7,450 MB/s read, 6,900 MB/s write
- Widely available, consumer pricing (~$300 each)
- Proven reliability in workstation use

**Future Upgrade Path:** Migrate to PCIe 5.0 NVMe when available (Epic 3+)

---

## Recommended "Single Source of Truth"

**Create New Document:** `docs/vault-cube-hardware-specification-v1.0.md`

**Contents:**
```markdown
# Vault Cube Hardware Specification v1.0

**Authoritative As Of:** 2025-10-29
**Supersedes:** Product Blueprint v3.0 hardware section
**Status:** CTO Approved

## Core Components
- **CPU:** AMD Ryzen Threadripper PRO 7975WX (32c/64t, 350W)
- **Motherboard:** ASUS Pro WS WRX90E-SAGE SE (preferred)
- **GPUs:** 4× NVIDIA GeForce RTX 5090 Founders Edition (~600W each)
- **RAM:** 256GB DDR5-6000 ECC RDIMM (Kingston Server Premier)
- **Storage:** 2× Samsung 990 Pro 4TB PCIe 4.0 NVMe SSD
- **PSU:** CORSAIR WS3000 - 3000W ATX 3.1 (80 PLUS Platinum)
- **OS:** Ubuntu 24.04 LTS (Noble Numbat)

## Power Budget
- CPU: 350W
- GPUs: 2,400W (4× 600W)
- Motherboard + RAM + Drives + Fans: 200W
- **Total:** ~2,950W (50W below PSU limit)

## Thermal Budget
- **Total Heat Output:** ~10,000 BTU/h
- **Cooling Required:** 12× Noctua Industrial PPC fans minimum
- **Airflow:** Intake (right face) → Exhaust (back face)
```

---

## Impact on Project Timeline

### If Decision Delayed:
- **Epic 1a cannot start** - Unclear which drivers to install
- **Test hardware procurement blocked** - Don't know which GPU to order
- **Power/thermal design uncertain** - 2,950W vs 1,250W is huge difference

### If Decision Made This Week:
- **Epic 1a can proceed** - Clear hardware target
- **Driver testing can begin** - Know which NVIDIA driver version to test
- **Thermal planning accurate** - Design cooling for actual heat load

**Recommendation:** **CTO decision by Friday EOD** to unblock Epic 1a Week 1

---

## Action Items

### Immediate (This Week)
1. **CTO Decision:** Approve GPU configuration (4× RTX 5090 recommended)
2. **Product Decision:** Confirm RAM configuration (256GB ECC recommended)
3. **Procurement:** Order 1× RTX 5090 for early testing ($2,500)
4. **Documentation:** Create authoritative `vault-cube-hardware-specification-v1.0.md`
5. **Communication:** Notify engineering team of final hardware spec

### Before Epic 1a Starts (Week 0)
6. **Update Product Blueprint v3.0** to match authoritative spec
7. **Update CLAUDE.md** if any conflicts remain
8. **Update Epic 1a tasks** to reference correct hardware
9. **Confirm storage model** (Samsung 990 Pro 4TB)

---

## Risks of Not Resolving

**CRITICAL RISK:** Starting Epic 1a with wrong hardware assumptions

**Scenario:** Epic 1a assumes 2× RTX 4090, but production uses 4× RTX 5090
- Driver installation fails (wrong driver version)
- Thermal testing invalid (2,400W vs 900W)
- Power budget wrong (PSU undersized)
- ML framework configuration incorrect (wrong CUDA settings)
- **Result:** Rework Epic 1a, 1-2 week delay

**Mitigation:** Resolve hardware spec conflicts before Epic 1a Week 1

---

## Recommended Decision Process

**Step 1:** CTO reviews this document (30 minutes)
**Step 2:** CTO approves recommended choices or provides alternatives (15 minutes)
**Step 3:** DevOps Lead creates authoritative hardware spec document (1 hour)
**Step 4:** Communicate to engineering team (15 minutes)
**Step 5:** Proceed with Epic 1a planning (Week 1 kickoff)

**Total Time:** 2 hours to resolve all conflicts

---

**Questions for CTO:**
1. Approve 4× RTX 5090 (vs 2× RTX 4090)?
2. Approve 256GB DDR5-6000 ECC (vs 128GB)?
3. Approve Ubuntu 24.04 LTS (vs 22.04 LTS)?
4. Approve Samsung 990 Pro 4TB (clarify "9100 Pro" typo)?
5. Authorize procurement of 1× RTX 5090 for testing ($2,500)?

---

**Document Version:** 1.0
**Created:** 2025-10-29
**Urgency:** **CRITICAL** - Decision required before Epic 1a Week 1
