# VirtualBox Testing Guide: Two-ISO Deployment

This guide documents how to test the Vault Cube two-ISO deployment process using VirtualBox. This simulates the bare-metal installation workflow.

## Overview

The deployment uses two ISOs:
1. **vault-cube-24.04-autoinstall.iso** - Installs Ubuntu 24.04 Server (base OS)
2. **vault-cube-desktop-packages.iso** - Adds Ubuntu Desktop (GNOME) offline

## Prerequisites

- VirtualBox installed
- Both ISOs in `output/` directory:
  - `output/vault-cube-24.04-autoinstall.iso` (~3.1GB)
  - `output/vault-cube-desktop-packages.iso` (~2.6GB)
- At least 35GB free disk space on host

## Part 1: Create VirtualBox VM

### Option A: Using VBoxManage (CLI)

```bash
# Create VM
VBoxManage createvm --name "vault-cube-test" --ostype Ubuntu_64 --register

# Configure VM
VBoxManage modifyvm "vault-cube-test" \
  --memory 4096 \
  --cpus 2 \
  --vram 128 \
  --graphicscontroller vmsvga \
  --nic1 nat \
  --boot1 dvd \
  --boot2 disk \
  --audio-enabled off

# Create 30GB virtual disk
VBoxManage createhd \
  --filename "$HOME/VirtualBox VMs/vault-cube-test/vault-cube-test.vdi" \
  --size 30720 \
  --format VDI

# Add storage controllers
VBoxManage storagectl "vault-cube-test" --name "SATA" --add sata --controller IntelAhci
VBoxManage storagectl "vault-cube-test" --name "IDE" --add ide

# Attach disk
VBoxManage storageattach "vault-cube-test" \
  --storagectl "SATA" --port 0 --device 0 \
  --type hdd \
  --medium "$HOME/VirtualBox VMs/vault-cube-test/vault-cube-test.vdi"

# Attach autoinstall ISO
VBoxManage storageattach "vault-cube-test" \
  --storagectl "IDE" --port 0 --device 0 \
  --type dvddrive \
  --medium "/path/to/output/vault-cube-24.04-autoinstall.iso"

# Add SSH port forwarding
VBoxManage modifyvm "vault-cube-test" --natpf1 "ssh,tcp,,2222,,22"
```

### Option B: Using VirtualBox GUI

1. **New VM**: Name: "vault-cube-test", Type: Linux, Version: Ubuntu (64-bit)
2. **Memory**: 4096 MB
3. **Hard disk**: Create new VDI, 30GB, dynamically allocated
4. **Settings → Storage**:
   - Add IDE Controller
   - Attach `vault-cube-24.04-autoinstall.iso` to IDE
5. **Settings → Network**: NAT, Port Forwarding: Host 2222 → Guest 22

## Part 2: Install Base OS (Autoinstall)

### Start the VM

```bash
# CLI
VBoxManage startvm "vault-cube-test" --type gui

# Or use VirtualBox GUI
```

### What Happens Automatically

1. VM boots from autoinstall ISO
2. Ubuntu installer runs unattended (~5-10 minutes)
3. System reboots automatically
4. Login prompt appears

### Verify Installation

```bash
# SSH into VM (after reboot)
ssh -p 2222 vaultadmin@127.0.0.1
# Password: vaultadmin

# Check system
df -h /
uname -a
```

## Part 3: Install Desktop (Offline)

### Swap the ISO

```bash
# CLI: Attach desktop ISO
VBoxManage storageattach "vault-cube-test" \
  --storagectl "IDE" --port 0 --device 0 \
  --type dvddrive \
  --medium "/path/to/output/vault-cube-desktop-packages.iso"
```

Or in VirtualBox GUI: Devices → Optical Drives → Choose disk image

### Mount and Install

```bash
# SSH into VM
ssh -p 2222 vaultadmin@127.0.0.1

# Mount the desktop ISO
sudo mkdir -p /mnt/desktop-iso
sudo mount /dev/sr0 /mnt/desktop-iso

# Verify mount
ls /mnt/desktop-iso/install-desktop-offline.sh

# Run the installer
sudo bash /mnt/desktop-iso/install-desktop-offline.sh /mnt/desktop-iso

# When prompted, type 'y' to continue
# Wait for installation (5-15 minutes)

# Reboot when complete
sudo reboot
```

## Part 4: Verify Desktop

### First Boot with Desktop

After reboot, you should see:
1. GNOME Display Manager (GDM) login screen
2. Click on "vaultadmin"
3. Click gear icon → Select "Ubuntu on Xorg" (recommended for VirtualBox)
4. Enter password: `vaultadmin`
5. GNOME desktop should appear

### Troubleshooting

**Black screen / No desktop elements:**
```bash
# Press Ctrl+Alt+F2 for terminal
# Login, then:
sudo apt install virtualbox-guest-x11 virtualbox-guest-utils
sudo reboot
```

**Login screen doesn't appear:**
```bash
sudo systemctl set-default graphical.target
sudo systemctl start gdm3
```

## Part 5: Cleanup

### Delete Test VM

```bash
# Power off if running
VBoxManage controlvm "vault-cube-test" poweroff

# Delete VM and all files
VBoxManage unregistervm "vault-cube-test" --delete
```

## Quick Reference Commands

```bash
# List VMs
VBoxManage list vms
VBoxManage list runningvms

# VM Info
VBoxManage showvminfo "vault-cube-test"

# Start/Stop
VBoxManage startvm "vault-cube-test" --type gui
VBoxManage startvm "vault-cube-test" --type headless
VBoxManage controlvm "vault-cube-test" poweroff
VBoxManage controlvm "vault-cube-test" reset

# Swap ISO while running
VBoxManage storageattach "vault-cube-test" \
  --storagectl "IDE" --port 0 --device 0 \
  --type dvddrive \
  --medium "/path/to/new.iso"

# Resize disk (VM must be off)
VBoxManage modifyhd "/path/to/disk.vdi" --resize 30720  # Size in MB

# SSH to VM
ssh -p 2222 vaultadmin@127.0.0.1
```

## Disk Space Requirements

| Phase | Disk Used | Free Needed |
|-------|-----------|-------------|
| Base server install | ~5GB | - |
| Desktop packages | ~10GB | 15GB+ |
| **Total recommended** | - | **25-30GB** |

## Default Credentials

- Username: `vaultadmin`
- Password: `vaultadmin`

## Notes

- VirtualBox Guest Additions improve graphics performance but aren't required
- "Ubuntu on Xorg" session is more stable than Wayland in VirtualBox
- Real bare-metal with NVIDIA GPUs won't have VirtualBox graphics issues
