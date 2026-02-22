# Ansible Role: nvidia

Installs NVIDIA GPU drivers, CUDA toolkit, and cuDNN for multi-GPU AI workloads.

## Supported Platforms

- Ubuntu 24.04 LTS
- Multi-GPU configurations (2x, 4x, 8x)
- NVIDIA GPUs: A100, H100, RTX 4090, RTX 5090

## Requirements

- Ubuntu 24.04 LTS with kernel 6.8+ (for RTX 40 series) or 6.13+ (for RTX 50 series)
- GCC 12+ (RTX 40 series) or GCC 14 (RTX 50 series)
- Internet access for package downloads (or local APT mirror)
- sudo/root access

## Role Variables

Available variables are listed below with default values (see `defaults/main.yml`):

```yaml
# GPU Architecture (auto-detected or manual override)
nvidia_gpu_architecture: "auto"  # Options: auto, ada-lovelace, blackwell

# Driver version based on architecture
nvidia_driver_version_ada: "535"        # RTX 40 series (Ada Lovelace)
nvidia_driver_version_blackwell: "570"  # RTX 50 series (Blackwell)

# Driver type (proprietary or open-source kernel modules)
nvidia_driver_type: "proprietary"  # Options: proprietary, open

# CUDA version
cuda_version: "12.4"

# cuDNN version
cudnn_version: "9.0"

# Kernel version requirements
kernel_version_minimum_ada: "6.5"
kernel_version_minimum_blackwell: "6.13"

# GCC requirements
gcc_version_minimum_ada: "12"
gcc_version_minimum_blackwell: "14"

# Reboot after driver installation
nvidia_reboot_after_install: true
nvidia_reboot_timeout: 300  # seconds
```

## Dependencies

- `ansible.builtin.apt` module
- `ansible.builtin.reboot` module

## Example Playbook

### Basic Multi-GPU Installation (A100, H100)

```yaml
- hosts: gpu_servers
  become: yes
  roles:
    - role: nvidia
      vars:
        nvidia_gpu_architecture: "auto"
        cuda_version: "12.4"
```

### RTX 4090 Installation (Ada Lovelace)

```yaml
- hosts: rtx_4090_servers
  become: yes
  roles:
    - role: nvidia
      vars:
        nvidia_gpu_architecture: "ada-lovelace"
        nvidia_driver_version_ada: "535"
        nvidia_driver_type: "proprietary"
        kernel_version_minimum_ada: "6.5"
```

### RTX 5090 Installation (Blackwell)

```yaml
- hosts: rtx_5090_servers
  become: yes
  roles:
    - role: nvidia
      vars:
        nvidia_gpu_architecture: "blackwell"
        nvidia_driver_version_blackwell: "570"
        nvidia_driver_type: "open"  # REQUIRED for RTX 50 series
        kernel_version_minimum_blackwell: "6.13"
        gcc_version_minimum_blackwell: "14"
```

## Tasks Overview

1. **GPU Detection** - Auto-detect GPU model and architecture
2. **Kernel Upgrade** - Ensure kernel version meets requirements
3. **GCC Installation** - Install required GCC version
4. **Driver Installation** - Install NVIDIA drivers (proprietary or open)
5. **CUDA Toolkit** - Install CUDA development toolkit
6. **cuDNN** - Install cuDNN for deep learning frameworks
7. **Validation** - Verify driver installation with nvidia-smi
8. **Reboot** - Reboot system to load new kernel modules

## Validation

After role execution, verify GPU access:

```bash
# Check driver version
nvidia-smi

# Check CUDA version
nvcc --version

# List all GPUs
nvidia-smi -L

# Check GPU topology (PCIe layout)
nvidia-smi topo -m

# Check for errors
dmesg | grep -i nvidia
```

## Multi-GPU Validation

```bash
# Verify all GPUs detected
nvidia-smi --query-gpu=count --format=csv,noheader

# Check GPU memory
nvidia-smi --query-gpu=index,name,memory.total --format=csv

# Monitor GPU utilization
watch -n 1 nvidia-smi
```

## Troubleshooting

### Issue: nvidia-smi shows "No devices found"

**Solution:**
```bash
# Check if driver loaded
lsmod | grep nvidia

# If not loaded, load manually
modprobe nvidia

# Check for errors
dmesg | grep nvidia
```

### Issue: CUDA version mismatch

**Solution:**
```bash
# Check CUDA version
nvcc --version

# Verify driver CUDA compatibility
nvidia-smi | grep "CUDA Version"

# Reinstall CUDA toolkit
apt install --reinstall cuda-toolkit-12-4
```

### Issue: RTX 5090 driver fails to load

**Solution:**
```bash
# Verify using open-source modules
apt list --installed | grep nvidia-driver

# Should see: nvidia-driver-570-server-open

# Check kernel version
uname -r  # Should be 6.13+

# Check GCC version
gcc --version  # Should be 14.x
```

## Architecture-Specific Notes

### Ada Lovelace (RTX 40 Series)
- Uses standard proprietary or open-source drivers
- Kernel 6.5+ sufficient
- GCC 12+ sufficient
- Well-tested, mature drivers

### Blackwell (RTX 50 Series)
- **REQUIRES** open-source kernel modules (`nvidia-driver-*-open`)
- **REQUIRES** kernel 6.13+
- **REQUIRES** GCC 14
- Newer architecture, less mature drivers

## Performance Tuning

### Enable Persistence Mode

```bash
# Enable persistence mode (reduces driver load time)
nvidia-smi -pm 1

# Make persistent across reboots
systemctl enable nvidia-persistenced
```

### Set Power Limits

```bash
# Set power limit (example: 400W for RTX 4090)
nvidia-smi -pl 400

# Query current power draw
nvidia-smi --query-gpu=power.draw --format=csv
```

### Configure Fan Curves

```bash
# Enable manual fan control
nvidia-smi -lgc 1500  # Lock GPU clock to 1500 MHz

# Set fan speed (requires X server for consumer GPUs)
nvidia-settings -a "[gpu:0]/GPUFanControlState=1"
nvidia-settings -a "[fan:0]/GPUTargetFanSpeed=80"
```

## License

MIT

## Author

Vault AI Systems
Epic 1a: Demo Box Operation
Task 1a.8: NVIDIA Drivers + CUDA Installation
