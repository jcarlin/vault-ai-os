# GCP GPU Validation Test Run

> **Date:** 2026-02-21
> **Branch:** `gpu-support`
> **Purpose:** Validate GPU Ansible roles on real hardware before Cube delivery

---

## Context

The GPU Ansible roles and `gpu.yml` playbook are committed on `gpu-support` branch but have **never been executed on real hardware**. Before delivering to the Cube, we do a GCP test run to catch role execution bugs (package not found, task ordering, template errors, etc.).

---

## GCP Account Status

| Resource | Status | Detail |
|----------|--------|--------|
| **Project** | `vault-ai-487703` | Active, config named `vault-cube-gpu` |
| **Billing** | Linked | `Deagle AI Production` (013011-FB785A-E3866B), open |
| **Compute API** | Enabled | `compute.googleapis.com` active |
| **Auth** | Active | `julianmcarlin@gmail.com` |
| **L4 GPU quota** | **1 GPU** | `NVIDIA_L4_GPUS: 0/1` in `us-central1` |
| **Preemptible L4** | **1 GPU** | `PREEMPTIBLE_NVIDIA_L4_GPUS: 0/1` |
| **Regular CPUs** | 200 | More than enough for g2-standard-8 (needs 8) |
| **Preemptible CPUs** | **0** | `PREEMPTIBLE_CPUS: 0/0` -- blocks spot instances |
| **SSD disk** | 500 GB | Enough for 100GB boot disk |
| **Existing instances** | None | Clean slate |

### Verdict: On-demand only (no preemptible/spot)

`PREEMPTIBLE_CPUS` quota is 0. Use on-demand instead:
- On-demand `g2-standard-8` (1x L4): ~$1.21/hr
- Full gpu.yml run (est. 45-75 min): ~$1.00-$1.50 total

---

## What GCP L4 Tests vs. Cube-Only

The L4 is Ada Lovelace architecture. The nvidia role auto-detects this and takes a **different code path** than Blackwell (RTX 5090).

| Component | L4 (Ada) code path | RTX 5090 (Blackwell) code path | Tested on GCP? |
|-----------|-------------------|-------------------------------|----------------|
| GPU detection (`detect_gpu.yml`) | Detects as ada-lovelace | Detects as blackwell | Yes |
| Kernel upgrade (`upgrade_kernel.yml`) | **Skipped** (6.5+ sufficient) | Upgrades to 6.13 | **No** |
| GCC upgrade (`install_gcc.yml`) | **Skipped** (system GCC fine) | Installs GCC 14 | **No** |
| Driver install (`install_driver.yml`) | `nvidia-driver-535` (proprietary) | `nvidia-driver-570-server-open` | Different package |
| CUDA 12.8 (`install_cuda.yml`) | Installs cuda-toolkit-12-8 | Same | Yes |
| cuDNN 9.7.1 (`install_cudnn.yml`) | Installs libcudnn9 | Same | Yes |
| Container toolkit | Merges daemon.json, restarts Docker | Same | Yes |
| PyTorch cu128 | pip install torch (cu128) | Same | Yes |
| TensorFlow NGC | docker pull nvcr.io container | Same | Yes |
| vLLM | pip install vllm | Same | Yes |
| Monitoring (nvtop, sysstat, etc.) | apt install | Same | Yes |
| Validation (`validate.yml`) | nvidia-smi, GPU count check | Same | Yes |
| Performance tuning | Persistence mode, power limit | Same | Yes |

**Bottom line:** GCP tests ~70% of the code paths. Catches all "stupid mistakes" -- wrong package names, task ordering, template rendering, daemon.json merge logic, pip install failures, Docker GPU passthrough.

---

## Plan: Manual VM Test Run (Option A)

### Step 1: Create on-demand L4 instance

```bash
gcloud compute instances create gpu-test-01 \
  --zone=us-central1-a \
  --machine-type=g2-standard-8 \
  --image-family=ubuntu-2404-lts-amd64 \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=100GB \
  --boot-disk-type=pd-balanced \
  --accelerator=type=nvidia-l4,count=1 \
  --maintenance-policy=TERMINATE \
  --tags=gpu-test \
  --no-restart-on-failure
```

### Step 2: SSH in and install Ansible

```bash
gcloud compute ssh gpu-test-01 --zone=us-central1-a

sudo apt-get update
sudo apt-get install -y software-properties-common
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt-get install -y ansible git
```

### Step 3: Clone repo

```bash
git clone --branch gpu-support https://github.com/jcarlin/vault-ai-os.git ~/vault-ai-os
cd ~/vault-ai-os/ansible
```

### Step 4: Run base system playbook

```bash
sudo ansible-playbook -i localhost, -c local playbooks/site.yml
```

### Step 5: Run GPU playbook

```bash
sudo ansible-playbook -i localhost, -c local playbooks/gpu.yml \
  -e '{"nvidia_gpu_architecture":"ada-lovelace","nvidia_expected_gpu_count":1}' -vv
```

Key overrides:
- `nvidia_gpu_architecture: ada-lovelace` -- force L4 code path
- `nvidia_expected_gpu_count: 1` -- GCP has 1 L4, not 4

### Step 6: After reboot, validate

```bash
gcloud compute ssh gpu-test-01 --zone=us-central1-a

nvidia-smi
python3.12 -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.device_count())"
python3.12 -c "from vllm import LLM; print('vLLM OK')"
```

### Step 7: Cleanup

```bash
gcloud compute instances delete gpu-test-01 --zone=us-central1-a --quiet
```

---

## Success Criteria

1. `site.yml` completes without errors on stock Ubuntu 24.04
2. `gpu.yml` pre-flight checks pass (Ubuntu 24.04, Docker, Python 3.12)
3. nvidia role installs driver, CUDA 12.8, cuDNN
4. Container toolkit merges into daemon.json **without clobbering** Docker settings
5. `nvidia-smi` shows 1x L4 GPU after reboot
6. PyTorch sees the GPU (`torch.cuda.is_available() == True`)
7. vLLM imports successfully
8. Second run of `gpu.yml` is idempotent (0 changed tasks)

---

## What This Doesn't Test (Cube-only)

- Kernel 6.13 upgrade path
- GCC 14 installation
- Open-source driver 570 (`nvidia-driver-570-server-open`)
- 4-GPU detection and multi-GPU validation
- Blackwell-specific GPU auto-detection via lspci

---

## Estimated Cost

- Instance: g2-standard-8, ~$1.21/hr
- Duration: 1.5-2 hours
- **Total: ~$2.00-$2.50**
