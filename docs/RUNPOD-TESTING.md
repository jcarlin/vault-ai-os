# GPU Testing Strategy: RunPod, GCP, and Bare Metal

Testing Packer/Ansible deployments for RTX 5090 (Blackwell) before deploying to physical hardware.

## Three-Layer Testing Architecture

### Layer 1: GCP Full Packer Builds (Complete Pipeline)

**Purpose**: Validate the entire Packer build lifecycle — driver install, kernel upgrade, module loading, Docker setup, image snapshot.

**GPU**: GCP G4 instances with **RTX PRO 6000 Blackwell Server Edition** (same sm_120 arch as RTX 5090).

**What this validates**:
- Full Packer image creation (create VM → provision → snapshot)
- Kernel upgrade to 6.13+ and reboot
- Open-source NVIDIA driver installation (`nvidia-driver-570-server-open`)
- CUDA 12.8, cuDNN 9.7.1, GCC 14
- Docker Engine + NVIDIA Container Toolkit
- NGC container pulls (TensorFlow, vLLM)
- System reboot behavior and driver persistence

**Configuration changes needed** in `packer/ubuntu-24.04/gcp-gpu-variables.pkr.hcl`:
```hcl
gcp_machine_type_build = "g4-standard-48"        # was g2-standard-4
gcp_gpu_type           = "nvidia-rtx-pro-6000"    # was nvidia-l4
nvidia_gpu_architecture = "blackwell"              # was ada-lovelace
```

**Cost**: Check [cloud.google.com/compute/gpus-pricing](https://cloud.google.com/compute/gpus-pricing). L4 preemptible fallback: ~$0.35/hr.

---

### Layer 2: RunPod RTX 5090 (ML Framework Validation)

**Purpose**: Validate that ML frameworks work on actual consumer RTX 5090 hardware with sm_120 compute capability.

**GPU**: RunPod RTX 5090 (~$0.69/hr Community, ~$0.89/hr Secure).

#### Why RunPod?

RunPod is one of the few cloud providers offering consumer GeForce RTX 5090. The major hyperscalers (GCP, AWS, Azure) only offer datacenter/professional GPUs. RunPod lets you test against the exact GPU in your Vault Cube.

#### Critical Limitation: Container-Based

RunPod pods are **Docker containers, not VMs**. The host kernel and NVIDIA drivers are managed by RunPod.

**What works on RunPod**:
- GPU detection (`lspci` detects RTX 5090)
- `nvidia-smi` (host driver exposed to container)
- Python 3.12 + pip package installation
- PyTorch cu128 installation and CUDA validation
- vLLM pip installation (for quick tests)
- GCC 14 installation
- apt package installation
- SSH access (with configuration)

**What does NOT work on RunPod**:
- Packer builds (requires VM creation/snapshotting)
- Kernel installation/upgrade (`modprobe` blocked in containers)
- NVIDIA driver installation from scratch (host-managed)
- Docker-in-Docker (host Docker daemon)
- System reboot
- systemd services
- NGC container pulls (no Docker access inside pod)
- TensorFlow NGC container validation

#### RunPod Quick Start

1. **Create a pod** via Python SDK:

```python
import runpod
runpod.api_key = "your_key"

pod = runpod.create_pod(
    name="vault-ai-blackwell-test",
    image_name="nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04",
    gpu_type_id="NVIDIA GeForce RTX 5090",
    gpu_count=1,
    cloud_type="SECURE",
    container_disk_in_gb=50,
    ports="22/tcp",
    env={"PUBLIC_KEY": "ssh-ed25519 AAAAC3..."}
)
```

2. **Configure Ansible inventory** — update `ansible/inventory/cloud.yml`:

```yaml
runpod-rtx5090:
  ansible_host: <runpod-ip>
  ansible_port: <runpod-port>
  ansible_user: root
  nvidia_gpu_architecture: "blackwell"
  nvidia_expected_gpu_count: 1
```

3. **Run the validation playbook** (skip container-incompatible tasks):

```bash
ansible-playbook -i inventory/cloud.yml playbooks/test-runpod-blackwell.yml
```

4. **Tear down** via API:

```python
runpod.terminate_pod(pod["id"])
```

**Cost per test run**: ~$0.35–$0.89 (30–60 minutes).

#### RunPod Ansible Role Compatibility

| Role | Works? | Notes |
|------|--------|-------|
| `common` | Mostly | Some sysctl changes may fail |
| `users` | Yes | User creation works |
| `packages` | Yes | apt works with root |
| `python` | Yes | Python 3.12 installs fine |
| `nvidia/detect_gpu` | Yes | lspci detects RTX 5090 |
| `nvidia/install_driver` | **No** | Host-managed drivers |
| `nvidia/upgrade_kernel` | **No** | Shared host kernel |
| `nvidia/install_cuda` | Partial | nvcc works, cuda-drivers blocked |
| `nvidia/install_cudnn` | Yes | Userspace library |
| `nvidia/validate` | Partial | nvidia-smi works, dmesg limited |
| `nvidia/performance_tuning` | Partial | Env vars work, nvidia-smi -pm fails |
| `pytorch` | Yes | Full install + GPU validation |
| `tensorflow` | **No** (NGC) | Requires Docker-in-Docker |
| `vllm` | **No** (NGC) | Requires Docker-in-Docker |
| `docker` | **No** | Host-managed Docker daemon |

**Key insight**: ~40-50% of Ansible roles work on RunPod. The driver installation pipeline — the core differentiator — cannot be tested here. Use RunPod specifically for validating PyTorch and CUDA compilation against sm_120 hardware.

---

### Layer 3: Physical Hardware (Final Validation)

**Purpose**: Validate the complete golden image on actual 2x/4x RTX 5090 bare-metal target.

After Layers 1 and 2 pass:
- Layer 1 (GCP G4) validated the full Packer build + Blackwell driver pipeline on sm_120
- Layer 2 (RunPod) validated ML frameworks against actual RTX 5090
- Remaining unknowns: multi-GPU P2P behavior, motherboard/BIOS interactions, NVMe performance, physical cooling

---

## RunPod API/CLI Reference

### Python SDK

```bash
pip install runpod
```

```python
import runpod
runpod.api_key = "your_key"

# List pods
pods = runpod.get_pods()

# Create pod
pod = runpod.create_pod(name="test", image_name="...", gpu_type_id="NVIDIA GeForce RTX 5090", ...)

# Get details
details = runpod.get_pod(pod["id"])

# Terminate
runpod.terminate_pod(pod["id"])
```

### CLI (`runpodctl`)

```bash
# Install: https://github.com/runpod/runpodctl
runpodctl get pod
runpodctl create pod --name test --gpuType "NVIDIA GeForce RTX 5090" --imageName "nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04"
runpodctl stop pod <id>
runpodctl remove pod <id>
```

### SkyPilot Integration

RunPod integrates with [SkyPilot](https://github.com/skypilot-org/skypilot) for multi-cloud GPU orchestration:

```yaml
# skypilot task
resources:
  accelerators: RTX5090:1
  cloud: runpod
setup: |
  pip install ansible
run: |
  ansible-playbook -i localhost, site.yml --tags=pytorch,vllm
```

---

## RunPod Pricing (Feb 2026)

| GPU | Community | Secure | VRAM | Architecture |
|-----|-----------|--------|------|-------------|
| RTX 5090 | ~$0.69/hr | ~$0.89/hr | 32 GB | Blackwell sm_120 |
| RTX 4090 | ~$0.44/hr | ~$0.54/hr | 24 GB | Ada sm_89 |
| A100 80GB | ~$1.33/hr | ~$1.64/hr | 80 GB | Ampere sm_80 |
| H100 80GB | ~$2.17/hr | ~$2.69/hr | 80 GB | Hopper sm_90 |
| B200 | N/A | ~$4.99/hr | 192 GB | Blackwell sm_100 |

Per-second billing. No egress fees. Default spend limit: $80/hr.

---

## Alternatives Considered

| Provider | RTX 5090? | Full VM? | Packer? | Best For |
|----------|-----------|----------|---------|----------|
| **GCP G4** | No (RTX PRO 6000) | Yes | **Yes** | Full Packer builds with Blackwell arch |
| **RunPod** | **Yes** | No (container) | No | ML framework validation on actual 5090 |
| **Lambda Labs** | No | Yes | No | Ansible-over-SSH (no image capture) |
| **Vast.ai (VM mode)** | Maybe | Yes | Partial | Full VM with community GPUs (availability varies) |
| **CoreWeave** | No | No (K8s) | No | Production K8s workloads |
| **Paperspace** | No | Yes | No | Limited GPU selection |

**Recommendation**: Use **GCP G4** for Layer 1 (full Packer builds) and **RunPod** for Layer 2 (RTX 5090 ML validation). Combined cost per test cycle: ~$1–$2.

---

## CUDA Compute Capability Warning

Ada Lovelace (sm_89) and Blackwell (sm_120) are **not binary-compatible**. A CUDA binary compiled for sm_89 will NOT run on sm_120 and vice versa. Testing on an RTX 4090 or L4 instance validates workflow structure but does NOT validate Blackwell CUDA kernel compatibility. You must test on sm_120 hardware (RTX 5090, RTX PRO 6000, or B200) for full validation.
