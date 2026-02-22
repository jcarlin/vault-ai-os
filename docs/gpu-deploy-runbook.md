# GPU Deploy Runbook — Vault Cube

Step-by-step instructions to install the GPU stack (NVIDIA drivers, CUDA, PyTorch, TensorFlow, vLLM) on a Cube that already has the base image.

---

## What's already on the Cube

The Packer base image (`site.yml`) + desktop layer already installed:

| Component | How it got there | Verify with |
|-----------|-----------------|-------------|
| Ubuntu 24.04 | Packer autoinstall | `lsb_release -a` |
| Python 3.12 | `python` Ansible role | `python3.12 --version` |
| Docker Engine | `docker` Ansible role | `docker --version` |
| Ansible | Packer shell provisioner (`ppa:ansible/ansible`) | `ansible --version` |
| git, curl, build-essential, etc. | `packages` Ansible role | `git --version` |
| OpenSSH server | `packages` role (openssh-server) | `systemctl status sshd` |

**Ansible is already installed.** The Packer build adds the `ppa:ansible/ansible` PPA and installs it via apt. It stays on the image — it's not cleaned up.

The Ansible *playbooks and roles*, however, are **not** on the Cube. During the Packer build they're staged to `/tmp/ansible` and cleaned up afterward. You need to get the repo onto the machine.

---

## 1. Get the Ansible code onto the Cube

**Option A: git clone (Cube has internet)**

```bash
# SSH into the Cube (or open a terminal on the desktop)
ssh vaultadmin@<CUBE_IP>

# Clone the repo
git clone https://github.com/jcarlin/vault-ai-os.git ~/vault-ai-os
cd ~/vault-ai-os/ansible
```

**Option B: scp from your Mac (if no internet or private repo)**

```bash
# From your Mac — tar up the repo and send it over:
cd ~/dev/vault-ai-systems
tar czf /tmp/vault-ai-os.tar.gz --exclude='.git' --exclude='packer/output-*' vault-ai-os/
scp /tmp/vault-ai-os.tar.gz vaultadmin@<CUBE_IP>:~/

# On the Cube — unpack:
ssh vaultadmin@<CUBE_IP>
tar xzf ~/vault-ai-os.tar.gz -C ~/
cd ~/vault-ai-os/ansible
```

**Option C: USB drive (fully air-gapped)**

```bash
# From your Mac — copy to USB:
cp /tmp/vault-ai-os.tar.gz /Volumes/USB_DRIVE/

# On the Cube — mount USB and unpack:
sudo mount /dev/sdb1 /mnt
tar xzf /mnt/vault-ai-os.tar.gz -C ~/
sudo umount /mnt
cd ~/vault-ai-os/ansible
```

### Quick sanity check

Once you're in `~/vault-ai-os/ansible`, verify the structure:

```bash
ls playbooks/       # Should show: gpu.yml  site.yml  test-common.yml
ls roles/           # Should show: common  docker  monitoring-basic  networking
                    #   nvidia  nvidia-container-toolkit  packages  pytorch
                    #   python  security  tensorflow  users  vllm
ansible --version   # Should show ansible [core 2.x.x]
```

## 2. Sanity check — verify base state

Run site.yml first. Everything should show "ok" with **zero** "changed" tasks. If anything changes, the machine drifted from the expected base state.

```bash
sudo ansible-playbook -i localhost, -c local playbooks/site.yml -vv
```

## 3. Install GPU stack

```bash
sudo ansible-playbook -i localhost, -c local playbooks/gpu.yml -vv
```

**What happens:**
1. Pre-flight checks (Ubuntu 24.04, Docker, Python 3.12)
2. NVIDIA driver install (kernel upgrade to 6.13 if needed, GCC 14, open-source driver 570)
3. **System reboots** after driver install to load kernel modules
4. Ansible exits (because the local connection dies on reboot)

## 4. After reboot — re-run

Log back in and run the same command again. Idempotent roles skip completed steps and continue with container toolkit, PyTorch, TensorFlow, vLLM, and monitoring tools.

```bash
sudo ansible-playbook -i localhost, -c local playbooks/gpu.yml -vv
```

## 5. Validate

```bash
# Quick check — should show your RTX 5090 GPU(s) (1x if single GPU, 2x when second is installed)
nvidia-smi

# Full validation (driver, CUDA, temps, PCIe, kernel)
bash ~/scripts/validate-gpus.sh

# Multi-GPU PyTorch test
python3.12 ~/scripts/test-pytorch-ddp.py
```

**Expected nvidia-smi output:**
- 1–2 GPUs listed (RTX 5090 FE — depends on how many are installed)
- Driver: 570.x+
- CUDA: 12.8

## 6. Test vLLM inference

**Option A: NGC container (recommended for Blackwell/RTX 5090)**

```bash
# Use the convenience script installed by the vllm Ansible role:
vllm-serve Qwen/Qwen2.5-32B-Instruct-AWQ

# Or run the container directly:
docker run --rm --gpus all -p 8001:8000 \
  nvcr.io/nvidia/vllm-inference:26.01-py3 \
  --model Qwen/Qwen2.5-32B-Instruct-AWQ \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9
```

**Option B: Direct Python (if not using NGC container)**

```bash
python3.12 -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen2.5-32B-Instruct-AWQ \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --port 8001
```

Test with curl from another terminal:
```bash
curl http://localhost:8001/v1/models
curl http://localhost:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen/Qwen2.5-32B-Instruct-AWQ","messages":[{"role":"user","content":"Hello"}]}'
```

---

## GCP Validation Results (Feb 21, 2026)

Full GPU stack validated on GCP L4 instance (closest available GPU to Blackwell architecture):

| Check | Result |
|-------|--------|
| NVIDIA driver 570 | ✅ Installed, nvidia-smi working |
| CUDA 12.8 | ✅ nvcc reports correct version |
| Container Toolkit | ✅ Docker GPU passthrough working |
| PyTorch 2.10+cu128 | ✅ torch.cuda.is_available() = True |
| TensorFlow (NGC) | ✅ GPU detected via NGC container |
| vLLM (NGC 26.01-py3) | ✅ Server starts, serves inference |
| All roles idempotent | ✅ Second run shows 0 changes |

One bug fixed during testing: vLLM NGC container tag corrected from `25.04-py3` to `26.01-py3`.

---

## Selective runs

Don't need the full stack? Use tags:

```bash
# Drivers + CUDA only
sudo ansible-playbook -i localhost, -c local playbooks/gpu.yml --tags nvidia -vv

# Container toolkit only (after drivers are working)
sudo ansible-playbook -i localhost, -c local playbooks/gpu.yml --tags nvidia-container -vv

# PyTorch + vLLM only (after drivers + CUDA are working)
sudo ansible-playbook -i localhost, -c local playbooks/gpu.yml --tags pytorch,vllm -vv

# Monitoring tools only
sudo ansible-playbook -i localhost, -c local playbooks/gpu.yml --tags monitoring -vv
```

---

## Troubleshooting

### nvidia-smi not found after reboot
Driver install didn't complete or kernel module didn't load.
```bash
dmesg | grep -i nvidia          # Check kernel logs
sudo modprobe nvidia             # Try loading module manually
ls /usr/lib/modules/$(uname -r)/kernel/drivers/video/nvidia*  # Check module exists
```

### Wrong kernel version (need 6.13+)
The nvidia role should handle this, but if it didn't:
```bash
uname -r                         # Check current kernel
sudo apt list --installed | grep linux-image   # Check installed kernels
# Re-run gpu.yml — the kernel upgrade task should catch it
```

### CUDA version mismatch
```bash
nvcc --version                   # Should show 12.8
cat /usr/local/cuda/version.json # Alternative check
ls /usr/local/cuda*              # Check CUDA installations
```

### Docker GPU access fails
```bash
docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi
# If this fails, check:
nvidia-container-cli info        # Container toolkit status
cat /etc/docker/daemon.json      # Should have nvidia runtime
sudo systemctl restart docker    # Restart Docker
```

### PyTorch doesn't see GPUs
```bash
python3.12 -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.device_count())"
# If False/0:
python3.12 -c "import torch; print(torch.version.cuda)"  # Should show 12.8
nvidia-smi                       # Drivers working?
```

### Ansible fails mid-run
Just re-run. All roles are idempotent — they skip completed steps.
```bash
sudo ansible-playbook -i localhost, -c local playbooks/gpu.yml -vv
```

### Check system logs
```bash
dmesg | grep -i nvidia | tail -20   # NVIDIA kernel messages
journalctl -u docker --no-pager     # Docker service logs
cat /var/log/syslog | grep -i gpu   # General GPU messages
```
