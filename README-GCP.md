# GCP GPU Validation - Quick Start Guide

**Project:** Vault Cube Golden Image - Epic 1a
**Task:** 1a.8 - NVIDIA Drivers + CUDA Validation
**Platform:** Google Cloud Platform (GCP) with L4 GPU
**Cost:** $3-5 total (FREE with $300 GCP new account credit)

---

## TL;DR - Fast Track (15 minutes)

```bash
# 1. Setup GCP environment (interactive)
./scripts/setup-gcp.sh

# 2. Reload shell to apply environment variables
exec -l $SHELL

# 3. Check GPU quota
./scripts/check-gcp-quotas.sh

# 4. Build GPU image (45-60 minutes)
cd packer/ubuntu-24.04
packer init .
packer build -only=cloud-gpu-gcp ubuntu-24.04-demo-box.pkr.hcl

# 5. Launch test instance
cd ..
./scripts/launch-gcp-gpu-test.sh

# 6. SSH and validate
gcloud compute ssh vault-cube-gpu-test-* --zone=us-central1-a
nvidia-smi
```

**Done!** You now have a GPU-enabled image running on GCP L4 GPU (Ada Lovelace - RTX 40/50 equivalent).

---

## Prerequisites

### Required
- ✅ macOS (you have this)
- ✅ Homebrew (you have this)
- ✅ Google account (create at https://accounts.google.com)
- ✅ Credit card (for GCP billing - won't be charged if using free credit)

### Will be installed automatically
- Google Cloud SDK (`gcloud` CLI)
- GCP project with billing enabled
- Service account for Packer
- SSH keys

---

## Step-by-Step Setup

### 1. Install Google Cloud SDK

```bash
# Install via Homebrew
brew install --cask google-cloud-sdk

# Add to your shell PATH (add to ~/.zshrc)
source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"

# Reload shell
exec -l $SHELL

# Verify installation
gcloud --version
```

### 2. Run Automated Setup

```bash
# Navigate to project directory
cd /Users/julian/dev/vault-ai-systems/cube-golden-image

# Run setup script (interactive)
./scripts/setup-gcp.sh
```

**What it does:**
1. Authenticates with Google (opens browser)
2. Creates GCP project: `vault-cube-gpu`
3. Links billing account (you'll select from list)
4. Enables Compute Engine & Storage APIs
5. Creates service account for Packer
6. Generates service account key → `~/.gcp/packer-gpu-builder-key.json`
7. Creates SSH key → `~/.ssh/gcp-vault-cube`
8. Checks GPU quota availability
9. Sets environment variables

**Time:** ~5 minutes (mostly clicking through browser auth)

### 3. Verify Setup

```bash
# Check quota and GCP configuration
./scripts/check-gcp-quotas.sh
```

**Expected output:**
```
✓ L4 GPU Quota in us-central1: 1-8 GPUs
✓ Ready to build GPU images!
```

**If quota is 0:**
- Follow instructions to request quota increase
- Typical approval time: 1-2 business days
- Can proceed with other setup in parallel

---

## Build GPU Image

### Option A: Recommended (Preemptible - 60% cheaper)

```bash
cd packer/ubuntu-24.04

# Initialize Packer (download plugins)
packer init .

# Validate configuration
packer validate -only=cloud-gpu-gcp ubuntu-24.04-demo-box.pkr.hcl

# Build with preemptible instance
packer build -only=cloud-gpu-gcp ubuntu-24.04-demo-box.pkr.hcl
```

**Time:** 45-60 minutes
**Cost:** ~$0.35

### Option B: On-Demand (More reliable)

```bash
cd packer/ubuntu-24.04

# Build with on-demand instance (no risk of termination)
packer build \
  -var 'gcp_use_preemptible=false' \
  -only=cloud-gpu-gcp \
  ubuntu-24.04-demo-box.pkr.hcl
```

**Time:** 45-60 minutes
**Cost:** ~$1.21

### What Gets Built

- Ubuntu 24.04 LTS
- NVIDIA Driver 570 (open-source, Blackwell support)
- CUDA Toolkit 12.8
- cuDNN 9.7
- Docker with GPU runtime
- Python 3.12
- PyTorch 2.10+ with CUDA 12.8
- TensorFlow (NGC container)
- vLLM 0.13.0 (NGC container)
- GPU monitoring tools

---

## Launch Test Instance

### Quick Launch (Defaults)

```bash
# Launch g2-standard-8 + L4 GPU (preemptible)
./scripts/launch-gcp-gpu-test.sh
```

**Instance specs:**
- Machine: g2-standard-8 (8 vCPU, 32GB RAM)
- GPU: 1× NVIDIA L4 (24GB VRAM, Ada Lovelace)
- Disk: 100GB SSD
- Preemptible: Yes (auto-shutdown after 2 hours)
- Cost: ~$0.48/hour

### Custom Launch

```bash
# Larger instance for heavy workloads
MACHINE_TYPE=g2-standard-16 ./scripts/launch-gcp-gpu-test.sh

# On-demand (no auto-shutdown)
PREEMPTIBLE=false ./scripts/launch-gcp-gpu-test.sh

# Custom name
INSTANCE_NAME=my-gpu-test ./scripts/launch-gcp-gpu-test.sh
```

---

## Validate GPU Installation

### Quick Validation

```bash
# SSH into instance
gcloud compute ssh vault-cube-gpu-test-* --zone=us-central1-a

# Check GPU
nvidia-smi

# Check CUDA
nvcc --version

# Check PyTorch
python3 -c "import torch; print(f'CUDA: {torch.cuda.is_available()}, GPUs: {torch.cuda.device_count()}')"
```

### Comprehensive Testing

```bash
# Run all validation scripts (on instance)
bash /home/vaultadmin/scripts/validate-gpus.sh
python3 /home/vaultadmin/scripts/test-pytorch-ddp.py
python3 /home/vaultadmin/scripts/test-tensorflow-multigpu.py
python3 /home/vaultadmin/scripts/test-vllm-inference.py

# Monitor GPU in real-time
bash /home/vaultadmin/scripts/monitor.sh
```

---

## Cleanup & Cost Management

### Quick Cleanup

```bash
# Delete instance (stop billing)
gcloud compute instances delete vault-cube-gpu-test-* --zone=us-central1-a

# Or run comprehensive cleanup
./scripts/cleanup-gcp-resources.sh
```

### What Gets Cleaned

- Running GPU instances
- Old custom images (keep latest 3)
- Unattached disks
- Snapshots (optional)

### View Costs

```bash
# Check billing
gcloud billing accounts list
gcloud billing projects describe vault-cube-gpu

# View in console
# https://console.cloud.google.com/billing?project=vault-cube-gpu
```

---

## Cost Breakdown

### Build Phase
| Activity | Instance | Time | Rate (Preemptible) | Cost |
|----------|----------|------|-------------------|------|
| Packer build | g2-standard-4 + L4 | 1 hr | $0.35/hr | $0.35 |

### Testing Phase
| Activity | Instance | Time | Rate (Preemptible) | Cost |
|----------|----------|------|-------------------|------|
| PyTorch validation | g2-standard-8 + L4 | 2 hrs | $0.48/hr | $0.96 |
| TensorFlow validation | g2-standard-8 + L4 | 1.5 hrs | $0.48/hr | $0.72 |
| vLLM validation | g2-standard-8 + L4 | 1.5 hrs | $0.48/hr | $0.72 |
| Documentation | g2-standard-4 + L4 | 1 hr | $0.35/hr | $0.35 |

**Total:** $3.10 (or **$0** with $300 free credit)

---

## Common Issues & Solutions

### Issue: "No GPU quota available"

**Solution:**
```bash
# Request quota increase
# 1. Visit: https://console.cloud.google.com/iam-admin/quotas?project=vault-cube-gpu
# 2. Filter: "L4 GPUs" + "us-central1"
# 3. Edit quota → Request 4-8 GPUs
# 4. Justification: "GPU-accelerated ML training for Vault Cube project"
# 5. Wait 1-2 business days
```

### Issue: "Service account key not found"

**Solution:**
```bash
# Re-run setup
./scripts/setup-gcp.sh

# Or manually export
export GOOGLE_APPLICATION_CREDENTIALS=~/.gcp/packer-gpu-builder-key.json
```

### Issue: "Packer build fails with authentication error"

**Solution:**
```bash
# Re-authenticate
gcloud auth application-default login

# Verify credentials
gcloud auth list
```

### Issue: "Instance creation fails - quota exceeded"

**Solution:**
```bash
# Check what's using quota
./scripts/check-gcp-quotas.sh

# Delete old instances
./scripts/cleanup-gcp-resources.sh
```

---

## Advanced Usage

### Legacy Ubuntu 22.04 Builds

The `packer/ubuntu-22.04/` directory contains legacy templates for Ubuntu 22.04 if needed.

### Multi-GPU Testing (when quota allows)

```bash
cd packer/ubuntu-24.04

# Modify Packer variables for 4 GPUs
packer build \
  -var 'gcp_gpu_count=4' \
  -var 'gcp_machine_type_build=g2-standard-32' \
  -only=cloud-gpu-gcp \
  ubuntu-24.04-demo-box.pkr.hcl
```

### Use Different GPU Type

```bash
cd packer/ubuntu-24.04

# Use T4 GPU (cheaper, older architecture)
packer build \
  -var 'gcp_gpu_type=nvidia-tesla-t4' \
  -var 'gcp_machine_type_build=n1-standard-4' \
  -only=cloud-gpu-gcp \
  ubuntu-24.04-demo-box.pkr.hcl
```

### Build in Different Region

```bash
cd packer/ubuntu-24.04

# Use Europe region
packer build \
  -var 'gcp_zone=europe-west4-a' \
  -only=cloud-gpu-gcp \
  ubuntu-24.04-demo-box.pkr.hcl
```

---

## Next Steps

### After Successful Validation

1. **Document Results**
   - Create validation report: `docs/gcp-gpu-validation-report.md`
   - Screenshot GPU benchmarks
   - Record costs incurred

2. **Update Epic 1a Status**
   - Mark task 1a.8 as complete
   - Update `docs/epic-1a-debu-box.md`
   - Document L4 GPU compatibility

3. **Prepare for RTX 5090 Migration**
   - Review `docs/gcp-validate-gpu-plan.md` → "Migration to RTX 5090" section
   - Update ansible variables for Blackwell architecture
   - Plan thermal management for 4× RTX 5090

4. **Optional: Deploy to Production**
   - Use validated GCP image for ML workloads
   - Scale to larger instances (g2-standard-16, g2-standard-32)
   - Implement auto-scaling based on load

---

## Helpful Commands

### GCP Management

```bash
# List all instances
gcloud compute instances list

# List custom images
gcloud compute images list --filter="family~vault-cube"

# Delete specific instance
gcloud compute instances delete INSTANCE_NAME --zone=ZONE

# SSH with port forwarding
gcloud compute ssh INSTANCE --zone=ZONE -- -L 8080:localhost:8080

# Copy files from instance
gcloud compute scp INSTANCE:/remote/path /local/path --zone=ZONE

# View instance serial console
gcloud compute instances get-serial-port-output INSTANCE --zone=ZONE
```

### Monitoring & Debugging

```bash
# Watch instance creation
watch -n 2 'gcloud compute instances list --filter="name~packer-"'

# View Packer logs (during build)
export PACKER_LOG=1
export PACKER_LOG_PATH=packer-debug.log

# Check billing
gcloud billing accounts list
gcloud billing projects describe vault-cube-gpu
```

---

## Resources

### Documentation
- **Complete Plan:** `docs/gcp-validate-gpu-plan.md` (572 lines, comprehensive)
- **Epic 1a Guide:** `docs/epic-1a-debu-box.md`
- **Cloud GPU Research:** `docs/cloud-gpu-setup-guide.md`

### Scripts
- **Setup:** `./scripts/setup-gcp.sh` (automated environment setup)
- **Quota Check:** `./scripts/check-gcp-quotas.sh`
- **Launch Instance:** `./scripts/launch-gcp-gpu-test.sh`
- **Cleanup:** `./scripts/cleanup-gcp-resources.sh`

### External Links
- GCP Console: https://console.cloud.google.com
- GCP Pricing: https://cloud.google.com/compute/all-pricing
- L4 GPU Info: https://cloud.google.com/compute/docs/gpus/gpu-platforms-pricing#l4
- Packer Docs: https://developer.hashicorp.com/packer/plugins/builders/googlecompute

---

## Support

**Issues?**
1. Check `docs/gcp-validate-gpu-plan.md` → Troubleshooting section
2. Run `./scripts/check-gcp-quotas.sh` for diagnostics
3. Check GCP console: https://console.cloud.google.com/compute

**Questions?**
- Review complete plan: `docs/gcp-validate-gpu-plan.md`
- Check ansible roles: `ansible/roles/nvidia/README.md`

---

**Document Version:** 1.0
**Last Updated:** 2025-01-11
**Project:** Vault Cube Golden Image - Epic 1a
**Estimated Total Time:** 2-3 hours (including build)
**Estimated Total Cost:** $3-5 (FREE with $300 GCP credit)
