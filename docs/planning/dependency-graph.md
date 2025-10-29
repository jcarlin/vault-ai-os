# Epic 1A Dependency Graph

## Task Dependency Matrix

### Dependency Levels

**Level 0: No Dependencies (Can Start Immediately)**
- Task 1a.1: Development Environment Setup (2-3h) [MacBook]
- Task 1a.2: Git Repository Structure (1h) [MacBook]

**Level 1: Depends on Level 0**
- Task 1a.3: Packer Template Creation (6-10h) [MacBook] → depends on 1a.1, 1a.2
- Task 1a.4: Ansible Base System (6-8h) [MacBook] → depends on 1a.3

**Level 2: Depends on Level 1**
- Task 1a.5: Ansible Security (4-6h) [MacBook] → depends on 1a.4
- Task 1a.6: Ansible Docker (3-4h) [MacBook] → depends on 1a.4
- Task 1a.7: Ansible Python (2-3h) [MacBook] → depends on 1a.4

**Level 3: GPU Hardware Required (Blocked Until Week 2)**
- Task 1a.8: NVIDIA Drivers + CUDA (8-12h) [GPU] → depends on 1a.4, GPU hardware
- Task 1a.16: Basic Monitoring (2-3h) [MacBook prep, GPU validation] → depends on 1a.8

**Level 4: GPU + Framework Dependencies**
- Task 1a.9: NVIDIA Container Toolkit (3-4h) [GPU] → depends on 1a.6, 1a.8
- Task 1a.10: PyTorch Installation (4-6h) [GPU] → depends on 1a.7, 1a.8
- Task 1a.11: TensorFlow Installation (4-6h) [GPU] → depends on 1a.7, 1a.8

**Level 5: Advanced Framework Dependencies**
- Task 1a.12: vLLM Installation (3-4h) [GPU] → depends on 1a.7, 1a.8, 1a.10

**Level 6: Validation Phase (Week 3)**
- Task 1a.13: GPU Detection Validation (4-6h) [GPU] → depends on 1a.8
- Task 1a.14: PyTorch Multi-GPU Validation (3-4h) [GPU] → depends on 1a.10, 1a.13
- Task 1a.15: vLLM Inference Validation (2-3h) [GPU] → depends on 1a.12, 1a.13

**Level 7: Documentation (Can Start Earlier)**
- Task 1a.17: Demo Box Setup Guide (4-6h) [MacBook] → depends on all above (soft dependency)

## Dependency Visualization

```
Level 0 (Parallel):
┌─────────┐  ┌─────────┐
│ 1a.1    │  │ 1a.2    │
│ Dev Env │  │ Git     │
└────┬────┘  └────┬────┘
     └─────┬──────┘
           │
Level 1:   ▼
      ┌─────────┐
      │ 1a.3    │
      │ Packer  │
      └────┬────┘
           │
           ▼
      ┌─────────┐
      │ 1a.4    │
      │ Ansible │
      │ Base    │
      └────┬────┘
           │
    ┌──────┼──────┐
    │      │      │
Level 2:
    ▼      ▼      ▼
┌───────┐┌───────┐┌───────┐
│ 1a.5  ││ 1a.6  ││ 1a.7  │
│Secure ││Docker ││Python │
└───┬───┘└───┬───┘└───┬───┘
    │        │        │
    │   ┌────┴────┐   │
    │   │         │   │
Level 3 (GPU Blocker):
    │   ▼         │   │
    │ ┌─────────┐│   │
    │ │ 1a.8    ││   │
    │ │ NVIDIA  ││   │
    │ │ Drivers ││   │
    │ └────┬────┘│   │
    │      │     │   │
    │      ├─────┘   │
    │      │         │
Level 4:
    │      ▼         │
    │ ┌─────────┐   │
    └─┤ 1a.16   │   │
      │Monitori.│   │
      └─────────┘   │
           │        │
      ┌────┼────┐   │
      │    │    │   │
      ▼    ▼    ▼   ▼
  ┌───────┐┌───────┐┌───────┐
  │ 1a.9  ││ 1a.10 ││ 1a.11 │
  │NV Con.││PyTorch││TensorF│
  └───────┘└───┬───┘└───────┘
               │
Level 5:       ▼
          ┌─────────┐
          │ 1a.12   │
          │ vLLM    │
          └────┬────┘
               │
    ┌──────────┼──────────┐
    │          │          │
Level 6:
    ▼          ▼          ▼
┌───────┐ ┌───────┐ ┌───────┐
│ 1a.13 │ │ 1a.14 │ │ 1a.15 │
│GPU Val│ │PyTorch│ │vLLM   │
│       │ │Val    │ │Val    │
└───┬───┘ └───┬───┘ └───┬───┘
    └─────┬────┴────┬────┘
          │         │
Level 7:  ▼         │
     ┌─────────┐    │
     │ 1a.17   │◄───┘
     │ Docs    │
     └─────────┘
```

## Critical Path Analysis

**Critical Path (Longest Sequential Chain):**
1. 1a.1 (3h) → 1a.2 (1h) → 1a.3 (10h) → 1a.4 (8h) → 1a.8 (12h) → 1a.10 (6h) → 1a.12 (4h) → 1a.15 (3h) → 1a.17 (6h)

**Total Critical Path Time: 53 hours**

**Parallelizable Branches:**

Branch A (Security): 1a.4 → 1a.5 (6h)
Branch B (Docker): 1a.4 → 1a.6 (4h) → 1a.9 (4h)
Branch C (Python/ML): 1a.4 → 1a.7 (3h) → 1a.10 (6h) → 1a.12 (4h)
Branch D (TensorFlow): 1a.4 → 1a.7 (3h) → 1a.11 (6h)
Branch E (Monitoring): 1a.8 → 1a.16 (3h)
Branch F (Validation): 1a.13 (6h) → 1a.14 (4h)

## Parallel Execution Opportunities

### Week 1 (MacBook-Only Tasks)

**Phase 1.1: Setup (Parallel)**
- Task 1a.1 + 1a.2 simultaneously (3h total, not 4h)

**Phase 1.2: Packer Development (Sequential)**
- Task 1a.3 (10h) - Must be sequential

**Phase 1.3: Ansible Roles (Parallel)**
After 1a.4 completes, these can run in parallel:
- Task 1a.5 (Security) - 6h
- Task 1a.6 (Docker) - 4h
- Task 1a.7 (Python) - 3h

**Optimization:** Run all three in parallel → 6h total (not 13h)

### Week 2 (GPU Hardware Required)

**Phase 2.1: NVIDIA Stack (Sequential)**
- Task 1a.8 (NVIDIA Drivers) - 12h - MUST be first
- Task 1a.16 (Monitoring prep) - 2h - Can start preparing playbook before GPU

**Phase 2.2: Framework Installation (Parallel)**
After 1a.8 completes, these can run in parallel:
- Task 1a.9 (NVIDIA Container) - 4h
- Task 1a.10 (PyTorch) - 6h
- Task 1a.11 (TensorFlow) - 6h

**Optimization:** Run all three in parallel → 6h total (not 14h)

**Phase 2.3: vLLM (Sequential)**
- Task 1a.12 (vLLM) - 4h - Depends on PyTorch completion

### Week 3 (Validation)

**Phase 3.1: Validation Tests (Parallel)**
- Task 1a.13 (GPU Detection) - 6h - Must be first
- Task 1a.14 (PyTorch DDP) + 1a.15 (vLLM) in parallel - 4h total

**Phase 3.2: Documentation (Can Start Earlier)**
- Task 1a.17 (Docs) - 6h - Can be written incrementally throughout

## Bottleneck Analysis

**Primary Bottleneck: Task 1a.8 (NVIDIA Drivers)**
- 12 hours of work
- Blocks all GPU-dependent tasks
- High risk of issues (new RTX 5090 hardware)
- Cannot parallelize

**Secondary Bottleneck: Task 1a.3 (Packer Template)**
- 10 hours of work
- Blocks all Ansible tasks
- Can reduce risk with cloud-init instead of preseed
- Cannot parallelize

**Tertiary Bottleneck: Task 1a.4 (Ansible Base)**
- 8 hours of work
- Blocks 5 downstream tasks
- Can parallelize downstream tasks after completion

## Dependencies Table

| Task | Depends On | Blocks | MacBook? | Hours |
|------|-----------|--------|----------|-------|
| 1a.1 | None | 1a.3 | ✅ | 2-3 |
| 1a.2 | None | 1a.3 | ✅ | 1 |
| 1a.3 | 1a.1, 1a.2 | 1a.4 | ✅ | 6-10 |
| 1a.4 | 1a.3 | 1a.5, 1a.6, 1a.7, 1a.8 | ✅ | 6-8 |
| 1a.5 | 1a.4 | None | ✅ | 4-6 |
| 1a.6 | 1a.4 | 1a.9 | ✅ | 3-4 |
| 1a.7 | 1a.4 | 1a.10, 1a.11, 1a.12 | ✅ | 2-3 |
| 1a.8 | 1a.4, GPU HW | 1a.9, 1a.10, 1a.11, 1a.12, 1a.13, 1a.16 | ❌ | 8-12 |
| 1a.9 | 1a.6, 1a.8 | None | ❌ | 3-4 |
| 1a.10 | 1a.7, 1a.8 | 1a.12, 1a.14 | ❌ | 4-6 |
| 1a.11 | 1a.7, 1a.8 | None | ❌ | 4-6 |
| 1a.12 | 1a.7, 1a.8, 1a.10 | 1a.15 | ❌ | 3-4 |
| 1a.13 | 1a.8 | 1a.14, 1a.15 | ❌ | 4-6 |
| 1a.14 | 1a.10, 1a.13 | 1a.17 | ❌ | 3-4 |
| 1a.15 | 1a.12, 1a.13 | 1a.17 | ❌ | 2-3 |
| 1a.16 | 1a.8 | None | ✅/❌ | 2-3 |
| 1a.17 | All above | None | ✅ | 4-6 |

## Optimization Insights

1. **Week 1 Can Be Compressed:**
   - Original estimate: 24-33 hours
   - With parallelization: 18-27 hours (6h saved)

2. **Week 2 Can Be Compressed:**
   - Original estimate: 22-32 hours
   - With parallelization: 16-26 hours (6h saved)

3. **Week 3 Relatively Optimized:**
   - Original estimate: 14-25 hours
   - With parallelization: 12-19 hours (2h saved)

4. **Documentation Can Start Earlier:**
   - Task 1a.17 can be written incrementally
   - Draft sections as tasks complete
   - Final assembly in Week 3

5. **Total Time Savings: 14 hours** (23% reduction)
