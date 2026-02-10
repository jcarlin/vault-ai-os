# Ubuntu 24.04 Packer Builds

## Quick Start - VirtualBox Local Build (No GPU)

```bash
# Initialize (one time only)
packer init local-dev-only.pkr.hcl

# Build (~30-45 minutes)
packer build local-dev-only.pkr.hcl
```

**Output**: `output-vault-cube-demo-box-2404/vault-cube-demo-box-2404.ova`

## Available Build Configurations

### 1. `local-dev-only.pkr.hcl` ✅ RECOMMENDED
- **Purpose**: Local VirtualBox development/testing
- **GPU**: None - base system only
- **Dependencies**: VirtualBox, Ansible
- **Build Time**: 30-45 minutes
- **Output**: OVA file

**What gets installed:**
- Ubuntu 24.04 LTS base system
- Common system packages
- Docker (no GPU support)
- Python 3.12
- ❌ NO NVIDIA drivers
- ❌ NO CUDA/cuDNN
- ❌ NO PyTorch/TensorFlow/vLLM

### 2. `ubuntu-24.04-demo-box.pkr.hcl` (Multi-build)
- **Contains 3 builds**: local-dev, cloud-gpu-gcp, baremetal-gpu
- **Warning**: Requires GCP and QEMU source files even with `-only` flag
- **Use case**: When you need multiple build targets

## Build Commands

### Standard Build
```bash
packer build local-dev-only.pkr.hcl
```

### Debug Mode (Recommended for First Run)
```bash
PACKER_LOG=1 packer build -debug local-dev-only.pkr.hcl 2>&1 | tee packer-local-dev-debug.log
```

Debug mode features:
- Pauses between each provisioner (press Enter to continue)
- Maximum verbosity with `PACKER_LOG=1`
- Saves complete log to file
- Allows SSH inspection between steps

## Pre-Build Checklist

```bash
# 1. Verify you're in the right directory
pwd
# Should show: .../cube-golden-image/packer/ubuntu-24.04

# 2. Check Packer version
packer version
# Should be >= 1.9.0

# 3. Verify Ubuntu 24.04 ISO exists
ls -lh /Users/julian/Downloads/ubuntu-24.04.3-live-server-amd64.iso
# Should show ~2.7GB file

# 4. Check VirtualBox is installed
VBoxManage --version
```

## Post-Build Validation

```bash
# 1. Check manifest was created
cat packer-manifest-local-2404.json

# 2. Verify OVA file size (should be ~2-3GB)
ls -lh output-vault-cube-demo-box-2404/*.ova

# 3. Import into VirtualBox
VBoxManage import output-vault-cube-demo-box-2404/vault-cube-demo-box-2404.ova

# 4. Boot and SSH test
# Start the VM, then:
ssh vaultadmin@<vm-ip>
# Password: vaultadmin

# 5. Verify no GPU components
which nvidia-smi       # Should NOT exist
which nvcc             # Should NOT exist
python3 -c "import torch" 2>&1 | grep "No module"  # Should show error
docker info | grep nvidia  # Should show nothing
```

## Package Configuration

Package installation is controlled by:
- `../../ansible/roles/packages/defaults/main.yml` - Package lists
- `../../ansible/roles/packages/tasks/main.yml` - Installation tasks

See `../../docs/ubuntu-24.04-build-plan.md` for complete documentation.

## Troubleshooting

### Error: "Unknown source googlecompute" or "Unknown source qemu"
**Solution**: Use `local-dev-only.pkr.hcl` instead of the multi-build template.

### Error: "ISO checksum mismatch"
**Solution**: Verify ISO download, or update checksum in variables section.

### Error: "SSH timeout"
**Solution**:
- Check VirtualBox VM is running
- Increase `ssh_timeout` and `ssh_handshake_attempts`
- Verify cloud-init completed: `cloud-init status --wait`

### Build hangs during cloud-init
**Solution**:
- Wait longer (cloud-init can take 5-10 minutes)
- Check console in VirtualBox GUI for errors
- Verify network connectivity in VM

## Files and Directories

```
packer/ubuntu-24.04/
├── local-dev-only.pkr.hcl          # Standalone VirtualBox build ✅
├── ubuntu-24.04-demo-box.pkr.hcl   # Multi-build template
├── sources-gcp.pkr.hcl              # GCP source definitions
├── sources-baremetal.pkr.hcl        # QEMU source definitions
├── gcp-gpu-variables.pkr.hcl        # GCP variables
├── baremetal-variables.pkr.hcl      # Baremetal variables
├── output-vault-cube-demo-box-2404/ # Build output directory
└── packer-manifest-local-2404.json  # Build manifest
```

## Documentation

Full documentation: `../../docs/ubuntu-24.04-build-plan.md`

Topics covered:
- Complete package configuration details
- QEMU troubleshooting guide
- GPU component inventory
- Success criteria
- Next steps after build
