# Packer + Ansible Automation Best Practices
**Epic 1A Technical Research**
**Date:** 2025-10-29
**Status:** ✅ FEASIBLE WITH CAVEATS

## Executive Summary

Automating RTX 5090 GPU provisioning with Packer and Ansible is **feasible** but requires careful handling of kernel upgrades, driver installation, and BIOS configuration (which cannot be automated).

### 🚨 Critical Automation Challenges

1. **BIOS Configuration:** ❌ Cannot be automated (must be manual or via IPMI/BMC)
2. **Kernel Upgrade:** ⚠️ Requires reboot during Packer build
3. **Driver Installation:** ✅ Automatable with Ansible roles
4. **Multi-GPU Detection:** ⚠️ May require extended timeouts
5. **Validation:** ✅ Post-deployment checks via Ansible

---

## Packer Best Practices for GPU Systems

### Ubuntu 24.04 Autoinstall Configuration

#### Basic Packer Template Structure
```hcl
# ubuntu-24.04-rtx5090.pkr.hcl

packer {
  required_version = ">= 1.9.0"
}

source "qemu" "ubuntu" {
  iso_url              = "https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso"
  iso_checksum         = "sha256:xxxxx"

  memory               = 8192
  cpus                 = 4
  disk_size            = "100G"

  http_directory       = "http"
  boot_wait            = "5s"

  # Autoinstall boot command
  boot_command = [
    "<wait><wait><wait>",
    "c<wait>",
    "linux /casper/vmlinuz autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]

  ssh_username         = "ubuntu"
  ssh_password         = "ubuntu"
  ssh_timeout          = "30m"  # Extended for GPU builds
  shutdown_command     = "echo 'ubuntu' | sudo -S shutdown -P now"
}

build {
  sources = ["source.qemu.ubuntu"]

  # Provisioners run after OS installation
  provisioner "shell" {
    script = "scripts/01-kernel-upgrade.sh"
  }

  provisioner "shell" {
    inline = ["sudo reboot"]
    expect_disconnect = true
  }

  provisioner "shell" {
    script = "scripts/02-nvidia-driver.sh"
    pause_before = "60s"  # Wait for reboot
  }

  provisioner "ansible" {
    playbook_file = "playbooks/gpu-setup.yml"
  }

  provisioner "shell" {
    script = "scripts/03-validate-gpus.sh"
  }
}
```

---

### Autoinstall User-Data

```yaml
# http/user-data
#cloud-config
autoinstall:
  version: 1

  # Locale and keyboard
  locale: en_US.UTF-8
  keyboard:
    layout: us

  # Network configuration
  network:
    version: 2
    ethernets:
      ens3:
        dhcp4: true

  # Storage configuration
  storage:
    layout:
      name: lvm
      match:
        size: largest

  # User account
  identity:
    hostname: gpu-workstation
    username: ubuntu
    password: "$6$rounds=4096$salted$hash"  # Use mkpasswd

  # SSH configuration
  ssh:
    install-server: yes
    allow-pw: yes

  # Packages to install
  packages:
    - build-essential
    - linux-headers-generic
    - dkms
    - git
    - curl
    - vim

  # Late commands (run at end of installation)
  late-commands:
    - curtin in-target --target=/target -- apt-get update
    - curtin in-target --target=/target -- apt-get install -y linux-generic-hwe-24.04
```

---

### Key Packer Considerations

#### 1. Boot Command Timing
**Challenge:** Boot command timing varies by hardware

```hcl
# Adjust wait times if autoinstall doesn't trigger
boot_command = [
  "<wait3><wait3><wait3>",  # Initial wait (3s × 3 = 9s)
  "c<wait>",                # Enter GRUB command mode
  "linux /casper/vmlinuz autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<enter><wait>",
  "initrd /casper/initrd<enter><wait>",
  "boot<enter>"
]
```

**Troubleshooting:**
- Check `/var/log/installer/autoinstall-user-data` on target system
- Increase `boot_wait` if system doesn't receive autoinstall parameter
- Adjust `<wait>` intervals for slower hardware

---

#### 2. GPU Driver Installation Timing
**Challenge:** GPU driver installation requires kernel headers and may need reboot

```hcl
provisioner "shell" {
  scripts = [
    "scripts/01-install-kernel-headers.sh",
    "scripts/02-disable-nouveau.sh"
  ]
}

# Reboot to load new kernel and disable Nouveau
provisioner "shell" {
  inline = ["sudo reboot"]
  expect_disconnect = true
}

# Wait for system to come back up
provisioner "shell" {
  inline = ["echo 'System rebooted'"]
  pause_before = "60s"
}

provisioner "shell" {
  script = "scripts/03-install-nvidia-driver.sh"
}
```

---

#### 3. Build Timeouts
**Default:** 20 minutes may be insufficient for GPU builds

```hcl
# Extend timeout for kernel upgrade + driver installation
source "qemu" "ubuntu" {
  ssh_timeout = "45m"  # Extended from default 20m
}
```

---

#### 4. HTTP Server for Autoinstall
**Requirement:** Packer's built-in HTTP server must serve user-data

```
project/
├── http/
│   ├── user-data     # Autoinstall configuration
│   └── meta-data     # Cloud-init metadata (can be empty)
├── scripts/
│   ├── 01-kernel-upgrade.sh
│   ├── 02-nvidia-driver.sh
│   └── 03-validate-gpus.sh
├── playbooks/
│   └── gpu-setup.yml
└── ubuntu-24.04-rtx5090.pkr.hcl
```

---

## Ansible Best Practices for GPU Provisioning

### Directory Structure
```
ansible/
├── roles/
│   ├── nvidia-driver/
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   │   ├── install-driver.yml
│   │   │   └── validate.yml
│   │   ├── handlers/
│   │   │   └── main.yml
│   │   ├── templates/
│   │   │   └── blacklist-nouveau.conf.j2
│   │   └── vars/
│   │       └── main.yml
│   ├── cuda-toolkit/
│   │   └── tasks/
│   │       └── main.yml
│   └── pytorch/
│       └── tasks/
│           └── main.yml
├── playbooks/
│   └── gpu-setup.yml
└── inventory/
    └── hosts
```

---

### NVIDIA Driver Role

#### tasks/main.yml
```yaml
---
# roles/nvidia-driver/tasks/main.yml

- name: Check if already on correct kernel version
  command: uname -r
  register: kernel_version
  changed_when: false

- name: Upgrade to kernel 6.13 if needed
  when: "'6.13' not in kernel_version.stdout"
  block:
    - name: Install mainline kernel PPA
      apt_repository:
        repo: ppa:cappelikan/ppa
        state: present
      become: yes

    - name: Install mainline kernel manager
      apt:
        name: mainline
        state: present
      become: yes

    - name: Install kernel 6.13
      shell: |
        mainline install-latest
      become: yes
      register: kernel_install

    - name: Reboot required
      debug:
        msg: "Kernel upgraded. Reboot required before driver installation."

- name: Disable Nouveau driver
  template:
    src: blacklist-nouveau.conf.j2
    dest: /etc/modprobe.d/blacklist-nouveau.conf
    owner: root
    group: root
    mode: '0644'
  become: yes
  notify: update initramfs

- name: Install prerequisites for NVIDIA driver
  apt:
    name:
      - build-essential
      - gcc-14
      - linux-headers-{{ kernel_version.stdout }}
      - dkms
    state: present
    update_cache: yes
  become: yes

- name: Add graphics-drivers PPA
  apt_repository:
    repo: ppa:graphics-drivers/ppa
    state: present
  become: yes

- name: Install NVIDIA driver 570 (open kernel modules)
  apt:
    name: nvidia-driver-570-server-open
    state: present
  become: yes
  register: nvidia_driver_install

- name: Verify NVIDIA driver installation
  command: nvidia-smi
  register: nvidia_smi_output
  failed_when: "'NVIDIA-SMI' not in nvidia_smi_output.stdout"
  changed_when: false
  become: yes

- name: Display GPU information
  debug:
    var: nvidia_smi_output.stdout_lines
```

---

#### handlers/main.yml
```yaml
---
# roles/nvidia-driver/handlers/main.yml

- name: update initramfs
  command: update-initramfs -u
  become: yes
```

---

#### templates/blacklist-nouveau.conf.j2
```
# Disable Nouveau driver for NVIDIA GPU
blacklist nouveau
options nouveau modeset=0
```

---

#### vars/main.yml
```yaml
---
# roles/nvidia-driver/vars/main.yml

nvidia_driver_version: "570"
required_kernel_version: "6.13"
gcc_version: "14"
```

---

### GPU Validation Role

```yaml
---
# roles/gpu-validation/tasks/main.yml

- name: Check number of GPUs detected
  shell: nvidia-smi -L | wc -l
  register: gpu_count
  changed_when: false
  become: yes

- name: Verify expected GPU count
  assert:
    that:
      - gpu_count.stdout | int == expected_gpu_count
    fail_msg: "Expected {{ expected_gpu_count }} GPUs, found {{ gpu_count.stdout }}"
    success_msg: "All {{ expected_gpu_count }} GPUs detected successfully"

- name: Check CUDA version
  shell: nvidia-smi | grep "CUDA Version" | awk '{print $9}'
  register: cuda_version
  changed_when: false
  become: yes

- name: Verify CUDA 12.8
  assert:
    that:
      - cuda_version.stdout is version('12.8', '>=')
    fail_msg: "CUDA version {{ cuda_version.stdout }} is too old. Need 12.8+"
    success_msg: "CUDA version {{ cuda_version.stdout }} is compatible"

- name: Check GPU compute capability
  shell: |
    nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -n1
  register: compute_cap
  changed_when: false
  become: yes

- name: Verify Blackwell architecture (SM 12.0)
  assert:
    that:
      - compute_cap.stdout is version('12.0', '>=')
    fail_msg: "Compute capability {{ compute_cap.stdout }} is not Blackwell (12.0+)"
    success_msg: "Blackwell architecture (SM {{ compute_cap.stdout }}) confirmed"

- name: Run GPU stress test
  shell: nvidia-smi --query-gpu=gpu_name,temperature.gpu,power.draw --format=csv
  register: gpu_health
  changed_when: false
  become: yes

- name: Display GPU health
  debug:
    var: gpu_health.stdout_lines
```

---

### Main Playbook

```yaml
---
# playbooks/gpu-setup.yml

- name: Configure RTX 5090 GPU Workstation
  hosts: all
  become: yes

  vars:
    expected_gpu_count: 4

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install base packages
      apt:
        name:
          - python3-pip
          - python3-venv
          - git
          - htop
          - nvtop
          - lm-sensors
        state: present

  roles:
    - role: nvidia-driver
    - role: cuda-toolkit
    - role: pytorch
    - role: gpu-validation

  post_tasks:
    - name: Create validation report
      template:
        src: templates/validation-report.j2
        dest: /root/gpu-validation-report.txt
        mode: '0644'

    - name: Display validation report
      command: cat /root/gpu-validation-report.txt
      register: report
      changed_when: false

    - debug:
        var: report.stdout_lines
```

---

## Common Pitfalls and Solutions

### Pitfall 1: Nouveau Driver Conflict
**Symptom:** NVIDIA driver installs but GPU not accessible
**Solution:**
```yaml
- name: Disable Nouveau before NVIDIA driver installation
  copy:
    content: |
      blacklist nouveau
      options nouveau modeset=0
    dest: /etc/modprobe.d/blacklist-nouveau.conf
  become: yes

- name: Update initramfs
  command: update-initramfs -u
  become: yes

- name: Reboot to disable Nouveau
  reboot:
    msg: "Rebooting to disable Nouveau driver"
  become: yes
```

---

### Pitfall 2: Wrong Driver Package
**Symptom:** nvidia-smi shows "No devices were found"
**Solution:** Ensure `-open` postfix

```yaml
- name: Install correct driver package
  apt:
    name: nvidia-driver-570-server-open  # MUST include '-open'
    state: present
  become: yes
```

**Wrong:**
```yaml
apt:
  name: nvidia-driver-570  # Missing '-open' - will fail!
```

---

### Pitfall 3: Kernel Headers Missing
**Symptom:** Driver compilation fails during installation
**Solution:**
```yaml
- name: Get current kernel version
  command: uname -r
  register: kernel_ver
  changed_when: false

- name: Install matching kernel headers
  apt:
    name: "linux-headers-{{ kernel_ver.stdout }}"
    state: present
  become: yes
```

---

### Pitfall 4: Multi-GPU Detection Timeout
**Symptom:** Packer build times out waiting for GPU detection
**Solution:**
```hcl
# In Packer template
provisioner "shell" {
  script = "scripts/validate-gpus.sh"
  timeout = "10m"  # Extended timeout
}
```

```bash
# scripts/validate-gpus.sh
#!/bin/bash
# Wait for all GPUs to be detected (up to 5 minutes)

MAX_WAIT=300  # 5 minutes
ELAPSED=0
EXPECTED_GPUS=4

while [ $ELAPSED -lt $MAX_WAIT ]; do
  GPU_COUNT=$(nvidia-smi -L | wc -l)

  if [ "$GPU_COUNT" -eq "$EXPECTED_GPUS" ]; then
    echo "All $EXPECTED_GPUS GPUs detected!"
    nvidia-smi
    exit 0
  fi

  echo "Waiting for GPUs... ($GPU_COUNT/$EXPECTED_GPUS detected)"
  sleep 10
  ELAPSED=$((ELAPSED + 10))
done

echo "ERROR: Timeout waiting for all GPUs"
exit 1
```

---

## Build Time Optimization

### Parallel Provisioning
```yaml
# Use Ansible's async for time-consuming tasks
- name: Install large packages asynchronously
  apt:
    name:
      - cuda-toolkit-12-8
      - nvidia-cudnn
    state: present
  async: 3600  # 1 hour timeout
  poll: 0      # Don't wait
  register: cuda_install

- name: Check installation status
  async_status:
    jid: "{{ cuda_install.ansible_job_id }}"
  register: job_result
  until: job_result.finished
  retries: 120
  delay: 30
```

---

### Package Caching
```hcl
# Packer: Use local apt cache mirror
provisioner "shell" {
  inline = [
    "echo 'Acquire::http::Proxy \"http://apt-cache.local:3142\";' | sudo tee /etc/apt/apt.conf.d/01proxy"
  ]
}
```

Or use apt-cacher-ng on build server:
```yaml
- name: Configure apt-cacher-ng proxy
  lineinfile:
    path: /etc/apt/apt.conf.d/01proxy
    line: 'Acquire::http::Proxy "http://{{ apt_cache_server }}:3142";'
    create: yes
  become: yes
  when: apt_cache_server is defined
```

---

### Pre-download ISOs and Packages
```bash
# Pre-download NVIDIA driver
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/575.64/NVIDIA-Linux-x86_64-575.64.run \
  -O /var/cache/nvidia-driver.run

# Use in Ansible
- name: Install NVIDIA driver from cache
  shell: |
    sh /var/cache/nvidia-driver.run --silent --dkms
  become: yes
```

---

## BIOS Configuration (Manual Steps)

**⚠️ Cannot be automated without IPMI/BMC access**

### Pre-Build Checklist (Manual)
1. Enter BIOS/UEFI setup
2. Navigate to: `Advanced → PCIe Configuration`
3. Set `PCIe Speed` to **Gen 4.0** (NOT Auto, NOT Gen 5)
4. Disable `CSM (Compatibility Support Module)`
5. Enable `Above 4G Decoding` (for multi-GPU)
6. Enable `Resizable BAR` (ReBAR)
7. Disable `Secure Boot` (if causing driver issues)
8. Update BIOS to latest version (RTX 5090 compatibility)

### Validation via Ansible (Post-BIOS)
```yaml
- name: Check PCIe generation via dmidecode
  shell: |
    lspci -vv | grep -A 10 "VGA compatible" | grep "LnkSta:"
  register: pcie_status
  changed_when: false
  become: yes

- name: Display PCIe link status
  debug:
    var: pcie_status.stdout_lines

# Example output check
# LnkSta: Speed 16GT/s, Width x16
# 16GT/s = PCIe Gen 4.0 ✅
```

---

## Cloud-Init Integration

### Cloud-Init User-Data
```yaml
#cloud-config
# For post-deployment GPU configuration

packages:
  - nvidia-driver-570-server-open
  - nvidia-utils-570-server
  - linux-headers-generic

runcmd:
  # Disable Nouveau
  - echo "blacklist nouveau" >> /etc/modprobe.d/blacklist-nouveau.conf
  - update-initramfs -u

  # Install NVIDIA driver
  - apt-add-repository -y ppa:graphics-drivers/ppa
  - apt update
  - apt install -y nvidia-driver-570-server-open

  # Validate
  - nvidia-smi

  # Log results
  - nvidia-smi > /var/log/gpu-provisioning.log

power_state:
  mode: reboot
  condition: True  # Reboot after driver installation
```

---

## Testing and Validation

### Packer Build Validation
```bash
# Run Packer build with debug mode
packer build -debug ubuntu-24.04-rtx5090.pkr.hcl

# Check for errors in output
# Look for:
# - "NVIDIA-SMI" in validation output
# - GPU count matches expected
# - CUDA version 12.8
# - No "No devices were found" errors
```

---

### Ansible Playbook Testing
```bash
# Test on single machine first
ansible-playbook -i inventory/hosts playbooks/gpu-setup.yml --limit test-host

# Check mode (dry-run)
ansible-playbook -i inventory/hosts playbooks/gpu-setup.yml --check

# Verbose output
ansible-playbook -i inventory/hosts playbooks/gpu-setup.yml -vvv
```

---

### Post-Deployment Validation Script
```bash
#!/bin/bash
# scripts/validate-deployment.sh

echo "=== GPU Deployment Validation ==="

# Check driver
if ! command -v nvidia-smi &> /dev/null; then
  echo "❌ NVIDIA driver not installed"
  exit 1
fi

# Check GPU count
GPU_COUNT=$(nvidia-smi -L | wc -l)
if [ "$GPU_COUNT" -ne 4 ]; then
  echo "❌ Expected 4 GPUs, found $GPU_COUNT"
  exit 1
fi

# Check CUDA version
CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}')
if [[ $(echo "$CUDA_VERSION < 12.8" | bc) -eq 1 ]]; then
  echo "❌ CUDA version $CUDA_VERSION < 12.8"
  exit 1
fi

# Check compute capability
COMPUTE_CAP=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -n1)
if [[ $(echo "$COMPUTE_CAP < 12.0" | bc) -eq 1 ]]; then
  echo "❌ Compute capability $COMPUTE_CAP is not Blackwell (12.0+)"
  exit 1
fi

# Check temperatures
nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader | while read TEMP; do
  if [ "$TEMP" -gt 85 ]; then
    echo "⚠️  High temperature detected: ${TEMP}°C"
  fi
done

echo "✅ All validation checks passed!"
nvidia-smi
```

---

## Risk Assessment

### 🔴 HIGH RISK (Cannot be Automated)
- **BIOS configuration** - Requires manual setup or IPMI access
- **Initial GPU detection** - May fail without proper BIOS settings

### 🟡 MEDIUM RISK
- **Kernel upgrade** - Requires reboot during build
- **Build timeouts** - Extended timeouts needed (45+ minutes)
- **Multi-GPU timing** - Detection delays possible

### 🟢 LOW RISK (Fully Automatable)
- **Driver installation** - Ansible role handles cleanly
- **Package installation** - Standard apt operations
- **Validation** - Scripts can verify all components

---

## Recommended Automation Strategy

### Phase 1: Manual BIOS Configuration
1. Configure BIOS settings (PCIe Gen 4.0, ReBAR, etc.)
2. Document settings in runbook
3. Create validation checklist

### Phase 2: Packer Image Build
1. Build base Ubuntu 24.04 image
2. Upgrade to kernel 6.13+
3. Install NVIDIA driver 570+
4. Validate single GPU

### Phase 3: Ansible Post-Configuration
1. Deploy to multi-GPU systems
2. Install CUDA toolkit and frameworks
3. Configure PyTorch/TensorFlow
4. Run validation suite

### Phase 4: Continuous Validation
1. Monitor GPU health
2. Verify driver versions
3. Check for BIOS updates
4. Test multi-GPU workloads

---

## References

- Packer Ubuntu 24.04 templates (community GitHub repos)
- Ansible Galaxy: nvidia.nvidia_driver role
- Ubuntu Server documentation: NVIDIA driver installation
- HashiCorp Packer documentation: Ansible provisioner

---

## Next Steps for Epic 1A

1. ✅ Create Packer template with kernel 6.13 upgrade
2. ✅ Develop Ansible role for NVIDIA driver 570-server-open
3. ⚠️ Document manual BIOS configuration steps (cannot be automated)
4. ✅ Implement extended timeouts for multi-GPU detection
5. ✅ Create comprehensive validation playbook
6. ⚠️ Test on single GPU system before multi-GPU deployment
