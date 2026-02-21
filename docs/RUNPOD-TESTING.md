# GPU Testing Strategy: RunPod, GCP, and Bare Metal

Testing Packer/Ansible deployments for RTX 5090 (Blackwell) before deploying to physical hardware.

## Three-Layer Testing Architecture

### Layer 1: GCP Full Packer Builds (Complete Pipeline)

**Purpose**: Validate the entire Packer build lifecycle — driver install, kernel upgrade, module loading, Docker setup, image snapshot.

**GPU**: GCP G2 instances with L4 GPUs (Ada Lovelace architecture) for Ansible validation. GCP G4 instances with RTX PRO 6000 (Blackwell) when available.

**What this validates**:
- Full Packer image creation (create VM, provision, snapshot)
- NVIDIA driver installation and CUDA toolkit
- Docker Engine + NVIDIA Container Toolkit
- NGC container pulls (TensorFlow, vLLM)
- System reboot behavior and driver persistence
- Idempotency (second run = 0 changes)

**Cost**: G2 with L4: ~$0.86/hr on-demand, ~$0.35/hr preemptible.

---

### Layer 2: RunPod RTX 5090 (ML Framework Validation)

**Purpose**: Validate that ML frameworks work on actual consumer RTX 5090 hardware with sm_120 compute capability.

**GPU**: RunPod RTX 5090 (~$0.69/hr Community, ~$0.89/hr Secure).

#### Why RunPod?

RunPod is one of the few cloud providers offering consumer GeForce RTX 5090. The major hyperscalers (GCP, AWS, Azure) only offer datacenter/professional GPUs. RunPod lets you test against the exact GPU in the Vault Cube.

#### Critical Limitation: Container-Based

RunPod pods are **Docker containers, not VMs**. The host kernel and NVIDIA drivers are managed by RunPod.

**What works on RunPod**:
- GPU detection (lspci detects RTX 5090)
- nvidia-smi (host driver exposed to container)
- Python 3.12 + pip package installation
- PyTorch cu128 installation and CUDA validation
- vLLM pip installation (for quick tests)
- GCC 14 installation
- apt package installation

**What does NOT work on RunPod**:
- Packer builds (requires VM creation/snapshotting)
- Kernel installation/upgrade (modprobe blocked in containers)
- NVIDIA driver installation from scratch (host-managed)
- Docker-in-Docker (host Docker daemon)
- System reboot
- systemd services
- NGC container pulls (no Docker access inside pod)

#### RunPod Ansible Role Compatibility

| Role | Works? | Notes |
|------|--------|-------|
| common | Mostly | Some sysctl changes may fail |
| users | Yes | User creation works |
| packages | Yes | apt works with root |
| python | Yes | Python 3.12 installs fine |
| nvidia/detect_gpu | Yes | lspci detects RTX 5090 |
| nvidia/install_driver | **No** | Host-managed drivers |
| nvidia/upgrade_kernel | **No** | Shared host kernel |
| nvidia/install_cuda | Partial | nvcc works, cuda-drivers blocked |
| nvidia/install_cudnn | Yes | Userspace library |
| nvidia/validate | Partial | nvidia-smi works, dmesg limited |
| nvidia/performance_tuning | Partial | Env vars work, nvidia-smi -pm fails |
| pytorch | Yes | Full install + GPU validation |
| tensorflow | **No** (NGC) | Requires Docker-in-Docker |
| vllm | **No** (NGC) | Requires Docker-in-Docker |
| docker | **No** | Host-managed Docker daemon |

**Key insight**: ~40-50% of Ansible roles work on RunPod. The driver installation pipeline cannot be tested here. Use RunPod specifically for validating PyTorch and CUDA compilation against sm_120 hardware.

---

### Layer 3: Physical Hardware (Final Validation)

**Purpose**: Validate the complete golden image on actual RTX 5090 bare-metal target.

After Layers 1 and 2 pass:
- Layer 1 (GCP) validated the full Ansible playbook + driver pipeline
- Layer 2 (RunPod) validated ML frameworks against actual RTX 5090
- Remaining unknowns: multi-GPU P2P behavior, motherboard/BIOS interactions, NVMe performance, physical cooling

---

## CUDA Compute Capability Warning

Ada Lovelace (sm_89) and Blackwell (sm_120) are **not binary-compatible**. A CUDA binary compiled for sm_89 will NOT run on sm_120 and vice versa. Testing on an L4 instance validates workflow structure but does NOT validate Blackwell CUDA kernel compatibility. You must test on sm_120 hardware (RTX 5090, RTX PRO 6000, or B200) for full validation.

---

## Cost Summary

| Provider | GPU | Hourly Cost | Best For |
|----------|-----|-------------|----------|
| GCP G2 | L4 (Ada) | ~$0.86/hr | Full Ansible validation |
| RunPod | RTX 5090 | ~$0.69-0.89/hr | ML framework on Blackwell |
| Physical Cube | RTX 5090 | N/A | Final end-to-end validation |

**Combined cost per test cycle**: ~$1-$3.
