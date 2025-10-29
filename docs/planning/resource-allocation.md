# Epic 1A Resource Allocation Strategy

## Resource Constraints

### Team Size
- **Current:** 1 engineer (assumed)
- **Optimal:** 2-3 engineers for maximum speed
- **Constraint:** Budget, availability

### Hardware Constraints
- **Week 1:** MacBook only (no GPU hardware)
- **Week 2:** MacBook + 4× RTX 5090 GPUs + full system
- **Blocker:** GPU hardware must arrive by Week 2 Monday

### Time Constraints
- **Deadline:** 3 weeks (15 business days)
- **Effort:** 60-90 hours baseline, 42-65h optimized
- **Daily capacity:** 6-8 hours sustainable

---

## Resource Allocation by Team Size

### Scenario 1: Solo Engineer (Baseline)

**Timeline:** 2-3 weeks
**Total Effort:** 42-65 hours
**Daily Average:** 4-6 hours

#### Week 1: Foundation (MacBook Only)
| Day | Tasks | Hours | Focus |
|-----|-------|-------|-------|
| Mon | 1a.1, 1a.2, start 1a.3 | 4h | Setup + Packer start |
| Tue | 1a.3 (Packer) | 8h | Packer development |
| Wed | 1a.4 (Ansible base) | 8h | Ansible foundation |
| Thu | 1a.5, 1a.6, 1a.7 (parallel) | 6h | Ansible roles |
| Fri | 1a.8 prep OR buffer | 4h | NVIDIA playbook prep |
| **Total** | | **30h** | Foundation complete |

**Key Strategy:** Front-load all MacBook-friendly tasks in Week 1

#### Week 2: GPU Stack (GPU Required)
| Day | Tasks | Hours | Focus |
|-----|-------|-------|-------|
| Mon | 1a.8 (NVIDIA drivers) | 12h | Critical path bottleneck |
| Tue | 1a.9, 1a.10, 1a.11 (parallel) | 6h | Framework installation |
| Wed | 1a.12, 1a.13 | 8h | vLLM + GPU validation |
| Thu | 1a.14, 1a.15 (parallel) | 4h | Multi-GPU testing |
| Fri | 1a.16, 1a.17 | 4h | Monitoring + docs |
| **Total** | | **34h** | AI stack complete |

**Key Strategy:** Leverage parallelization on Tuesday/Thursday

#### Week 3: Polish (Optional)
| Day | Tasks | Hours | Focus |
|-----|-------|-------|-------|
| Mon | Stress test start + monitoring | 4h | 24h test initiated |
| Tue | Stress test analysis + docs | 4h | Final validation |
| Wed | Buffer / handoff | 2h | Contingency |
| **Total** | | **10h** | Polish complete |

**Total Solo Effort: 74 hours over 3 weeks (sustainable pace)**

---

### Scenario 2: Team of 2 Engineers

**Timeline:** 1.5-2 weeks
**Total Effort:** 21-33 hours per engineer
**Daily Average:** 3-4 hours per engineer

#### Engineer 1: Infrastructure Specialist
**Focus:** Packer, Ansible, NVIDIA stack, system-level work

| Week | Tasks | Hours |
|------|-------|-------|
| Week 1 | 1a.1, 1a.2, 1a.3, 1a.4, 1a.5, 1a.6 | 24h |
| Week 2 | 1a.8, 1a.9, 1a.13, 1a.16 | 20h |
| **Total** | | **44h** |

#### Engineer 2: ML Frameworks Specialist
**Focus:** Python, PyTorch, TensorFlow, vLLM, validation, documentation

| Week | Tasks | Hours |
|------|-------|-------|
| Week 1 | 1a.7, write 1a.10/1a.11/1a.12 playbooks, prep validation scripts | 12h |
| Week 2 | 1a.10, 1a.11, 1a.12, 1a.14, 1a.15, 1a.17 | 22h |
| **Total** | | **34h** |

**Parallelization Benefits:**
- Week 1: Engineer 2 can prep while Engineer 1 builds foundation
- Week 2: Both execute in parallel (infrastructure vs frameworks)
- Total time: 1.5 weeks vs 3 weeks solo (50% faster)

**Handoff Points:**
- End of Week 1 Day 3: Engineer 1 completes 1a.4 → Engineer 2 can start 1a.7
- End of Week 2 Day 1: Engineer 1 completes 1a.8 → Engineer 2 can start 1a.10/1a.11

---

### Scenario 3: Team of 3 Engineers

**Timeline:** 1 week
**Total Effort:** 14-22 hours per engineer
**Daily Average:** 3-4 hours per engineer

#### Engineer 1: Infrastructure + Packer
**Focus:** Development environment, Packer, Ansible base, Docker

| Week | Tasks | Hours |
|------|-------|-------|
| Week 1 | 1a.1, 1a.2, 1a.3, 1a.4, 1a.6 | 28h |
| **Total** | | **28h** |

#### Engineer 2: NVIDIA + PyTorch
**Focus:** NVIDIA stack, PyTorch, multi-GPU validation

| Week | Tasks | Hours |
|------|-------|-------|
| Week 1 | 1a.8, 1a.9, 1a.10, 1a.13, 1a.14, 1a.16 | 32h |
| **Total** | | **32h** |

#### Engineer 3: TensorFlow + vLLM + Docs
**Focus:** Python, TensorFlow, vLLM, validation, documentation

| Week | Tasks | Hours |
|------|-------|-------|
| Week 1 | 1a.7, 1a.11, 1a.12, 1a.15, 1a.17 | 24h |
| **Total** | | **24h** |

**Ultra-Parallelization Benefits:**
- All three engineers work simultaneously
- Minimal dependencies (1a.4 and 1a.8 still block some work)
- Total time: 1 week vs 3 weeks solo (66% faster)
- Requires excellent coordination

**Coordination Requirements:**
- Daily standups (15 min)
- Shared documentation (real-time updates)
- Clear handoff protocols
- Overlap on critical path items

---

## MacBook vs GPU Resource Allocation

### MacBook-Only Tasks (Week 1)
**Can start immediately without GPU hardware**

| Task | Hours | Complexity | Risk |
|------|-------|------------|------|
| 1a.1: Dev Environment | 2-3h | Low | Low |
| 1a.2: Git Repo | 1h | Low | Low |
| 1a.3: Packer Template | 6-10h | High | Medium |
| 1a.4: Ansible Base | 6-8h | Medium | Low |
| 1a.5: Ansible Security | 4-6h | Medium | Low |
| 1a.6: Ansible Docker | 3-4h | Low | Low |
| 1a.7: Ansible Python | 2-3h | Low | Low |
| **Total** | **24-33h** | | |

**Strategy:** Complete all MacBook tasks in Week 1 to unblock Week 2

---

### GPU-Required Tasks (Week 2+)
**Blocked until GPU hardware arrives**

| Task | Hours | GPU Count | Risk |
|------|-------|-----------|------|
| 1a.8: NVIDIA Drivers | 8-12h | 1-4 GPUs | High |
| 1a.9: NVIDIA Container | 3-4h | 1+ GPU | Low |
| 1a.10: PyTorch | 4-6h | 1+ GPU | Medium |
| 1a.11: TensorFlow | 4-6h | 1+ GPU | Medium |
| 1a.12: vLLM | 3-4h | 1+ GPU | Medium |
| 1a.13: GPU Validation | 4-6h | 4 GPUs | Medium |
| 1a.14: PyTorch DDP | 3-4h | 4 GPUs | Medium |
| 1a.15: vLLM Inference | 2-3h | 1 GPU | Low |
| **Total** | **31-45h** | | |

**Critical Blocker:** Task 1a.8 (NVIDIA Drivers) must complete before all others

---

### Hybrid Tasks (Can Prep on MacBook, Test on GPU)

| Task | MacBook Work | GPU Work | Total |
|------|--------------|----------|-------|
| 1a.8: NVIDIA Drivers | Write Ansible playbook (4h) | Test on hardware (8h) | 12h |
| 1a.10: PyTorch | Write playbook (2h) | Test installation (4h) | 6h |
| 1a.11: TensorFlow | Write playbook (2h) | Test installation (4h) | 6h |
| 1a.12: vLLM | Write playbook (1h) | Test installation (3h) | 4h |
| 1a.16: Monitoring | Write playbook (2h) | Validate on GPU (1h) | 3h |
| **Total** | **11h** | **20h** | **31h** |

**Optimization:** Do 11h of prep work on MacBook in Week 1, reducing Week 2 to 20h

---

## Early GPU Procurement Strategy

### Option 1: Single RTX 5090 in Week 1
**Cost:** ~$3,500
**Benefit:** Start GPU tasks 1 week early

| Metric | Without Early GPU | With Early GPU | Improvement |
|--------|-------------------|----------------|-------------|
| Week 1 effort | 24-33h | 36-45h | Start GPU work |
| Week 2 effort | 22-32h | 12-18h | Reduced |
| Total calendar time | 3 weeks | 2 weeks | 1 week saved |
| Risk reduction | - | High | Early driver testing |

**Recommendation:** Procure 1× RTX 5090 immediately if budget allows

**Risk Mitigation:**
- Test NVIDIA driver installation in Week 1
- Identify driver compatibility issues early
- Validate PCIe 5.0 support
- Confirm 4-GPU system will work before full purchase

---

### Option 2: Wait for Full 4-GPU System
**Cost:** $0 additional
**Benefit:** Lower upfront cost

| Metric | Value |
|--------|-------|
| Week 1 effort | 24-33h (MacBook only) |
| Week 2 effort | 22-32h (GPU work starts) |
| Total calendar time | 3 weeks |
| Risk | High (no early validation) |

**Risk:** If driver issues occur, no buffer time to resolve

---

## Resource Contention Analysis

### GPU Resource Contention

**Low Contention Tasks (Can Run Simultaneously):**
- Installation tasks (1a.9, 1a.10, 1a.11, 1a.12) - no GPU usage during install
- Validation on different GPUs (1a.14 on GPU 0-1, 1a.15 on GPU 2-3)

**High Contention Tasks (Must Run Sequentially):**
- NVIDIA driver installation (1a.8) - system-level, affects all GPUs
- Full 4-GPU tests (1a.13, 1a.14 with all GPUs)

**Contention Resolution:**
```bash
# Example: Run PyTorch DDP and vLLM simultaneously
Terminal 1: CUDA_VISIBLE_DEVICES=0,1 python scripts/test-pytorch-ddp.py
Terminal 2: CUDA_VISIBLE_DEVICES=2,3 python scripts/test-vllm-inference.py
```

---

### Disk I/O Contention

**High I/O Tasks:**
- 1a.3: Packer builds (ISO download, disk writes)
- 1a.8: NVIDIA package downloads (large files)
- 1a.10, 1a.11, 1a.12: ML framework downloads (PyTorch 2GB+, TensorFlow 500MB+)

**Mitigation:**
- Pre-download packages before installation
- Use local package cache
- Run installations sequentially if disk I/O is slow
- Consider NVMe SSD for faster builds

---

### Network Bandwidth Contention

**High Bandwidth Tasks:**
- Package downloads (CUDA 3GB+, PyTorch 2GB+, TensorFlow 500MB+)
- Model downloads for vLLM (Llama-2-7B ~14GB)

**Mitigation:**
- Schedule downloads during low-usage times
- Use local package mirrors if available
- Download models overnight
- Parallel downloads for different packages (no contention)

---

## Resource Allocation Decision Matrix

### When to Use Solo Engineer
- **Budget:** Limited
- **Timeline:** 3 weeks acceptable
- **Complexity:** Manageable with one person
- **Knowledge:** Single engineer has full stack knowledge
- **Recommendation:** Default option for cost efficiency

### When to Use Team of 2
- **Budget:** Moderate
- **Timeline:** 2 weeks required
- **Complexity:** High (NVIDIA + ML frameworks)
- **Knowledge:** Can split infrastructure vs ML expertise
- **Recommendation:** Best balance of speed and cost

### When to Use Team of 3
- **Budget:** Higher
- **Timeline:** 1 week required (urgent)
- **Complexity:** Very high (need parallel execution)
- **Knowledge:** Specialists for Packer/Ansible, NVIDIA, ML frameworks
- **Recommendation:** Only for time-critical projects

---

## Resource Optimization Recommendations

### Top 5 Optimizations

1. **Procure 1× RTX 5090 Early ($3,500)**
   - Benefit: 1 week calendar time savings
   - ROI: High (early driver validation, reduced risk)

2. **Pre-Download All Packages (4h effort)**
   - Benefit: Eliminate download wait time
   - ROI: High (saves 2-3h during installation)

3. **Use Ansible Parallelization (0h effort)**
   - Benefit: Run roles simultaneously
   - ROI: Very high (18h time savings)

4. **Incremental Documentation (0h effort)**
   - Benefit: Spread documentation work across 3 weeks
   - ROI: High (better quality, less end-of-project crunch)

5. **Prepare Playbooks on MacBook (11h effort)**
   - Benefit: Reduce GPU hardware wait time
   - ROI: High (11h of Week 2 work moved to Week 1)

### Cost-Benefit Analysis

| Optimization | Cost | Time Saved | ROI |
|--------------|------|------------|-----|
| Early GPU procurement | $3,500 | 1 week | High |
| Team of 2 engineers | 1× salary | 1 week | Medium |
| Team of 3 engineers | 2× salary | 2 weeks | Low |
| Ansible parallelization | $0 | 18h | Very high |
| Incremental docs | $0 | 4h | High |
| Pre-download packages | $0 | 3h | High |

**Recommended:** Early GPU + Ansible parallelization + incremental docs (highest ROI)

---

## Knowledge Transfer Requirements

### If Solo Engineer
- **Risk:** Single point of failure
- **Mitigation:**
  - Document everything incrementally
  - Create detailed setup guide (1a.17)
  - Record demo videos
  - Write troubleshooting runbooks

### If Team of 2-3 Engineers
- **Risk:** Knowledge silos
- **Mitigation:**
  - Daily standups (15 min)
  - Shared documentation (real-time)
  - Pair programming for critical tasks (1a.8)
  - Cross-training sessions
  - Code reviews for all Ansible roles

---

## Summary: Optimal Resource Allocation

**Recommended Configuration:**
- **Team Size:** 1 engineer (solo) with early GPU procurement
- **Timeline:** 2 weeks (vs 3 weeks baseline)
- **Strategy:**
  - Week 1: Complete all MacBook tasks + start NVIDIA drivers on 1 GPU
  - Week 2: Complete all ML frameworks + validation on 4 GPUs
- **Investment:** $3,500 (single RTX 5090)
- **Effort:** 42-65 hours (vs 60-90h baseline)
- **Risk:** Low (early driver validation reduces Week 2 risk)

**Alternative (Budget-Constrained):**
- **Team Size:** 1 engineer without early GPU
- **Timeline:** 3 weeks
- **Strategy:**
  - Week 1: Complete all MacBook tasks
  - Week 2: Complete all GPU tasks (assumes hardware arrives Monday)
  - Week 3: Validation + stress testing + documentation
- **Investment:** $0 additional
- **Effort:** 60-75 hours (with risk buffer)
- **Risk:** Medium (no early driver validation)

**Key Insight:** Early GPU procurement provides the best ROI for calendar time reduction and risk mitigation. Solo engineer is sufficient if work is properly sequenced and parallelized via automation.
