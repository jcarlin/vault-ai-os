# VirtualBox Full Test Guide: Autoinstall ISO → Desktop with Guest Additions

Complete steps to test the two-ISO deployment workflow in VirtualBox.

## Prerequisites

- VirtualBox installed on host machine
- `vault-cube-24.04-autoinstall.iso` (base server install)
- `vault-cube-desktop-packages.iso` (offline desktop packages)

---

## Phase 1: Create VM (on host)

```bash
# Create and configure VM
VBoxManage createvm --name "vault-cube-test" --ostype Ubuntu_64 --register
VBoxManage modifyvm "vault-cube-test" --memory 4096 --cpus 2 --vram 128 --graphicscontroller vmsvga --nic1 nat

# Create 30GB virtual disk
VBoxManage createhd --filename "$HOME/VirtualBox VMs/vault-cube-test/vault-cube-test.vdi" --size 30720

# Add storage controllers
VBoxManage storagectl "vault-cube-test" --name "SATA" --add sata --controller IntelAhci
VBoxManage storagectl "vault-cube-test" --name "IDE" --add ide

# Attach disk and autoinstall ISO
VBoxManage storageattach "vault-cube-test" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$HOME/VirtualBox VMs/vault-cube-test/vault-cube-test.vdi"
VBoxManage storageattach "vault-cube-test" --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium /path/to/vault-cube-24.04-autoinstall.iso

# Set boot order and enable SSH port forwarding
VBoxManage modifyvm "vault-cube-test" --boot1 dvd --boot2 disk
VBoxManage modifyvm "vault-cube-test" --natpf1 "ssh,tcp,,2222,,22"

# Start VM
VBoxManage startvm "vault-cube-test"
```

---

## Phase 2: Autoinstall (automatic)

- **Duration:** ~7-10 minutes
- VM boots from ISO and installs Ubuntu Server automatically
- No user interaction required
- After completion, VM reboots to login prompt

**Login credentials:**
- Username: `vaultadmin`
- Password: `vaultadmin`

---

## Phase 3: Install Guest Additions

### 3a. Install build dependencies (in VM)

```bash
sudo apt-get update
sudo apt-get install -y build-essential linux-headers-$(uname -r) bzip2
```

### 3b. Attach Guest Additions ISO (on host)

```bash
VBoxManage storageattach "vault-cube-test" --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium additions --forceunmount
```

### 3c. Install Guest Additions (in VM)

```bash
sudo mkdir -p /mnt/cdrom
sudo mount /dev/cdrom /mnt/cdrom
sudo /mnt/cdrom/VBoxLinuxAdditions.run
sudo reboot
```

---

## Phase 4: Install Desktop Packages

### 4a. Attach desktop ISO (on host)

```bash
VBoxManage storageattach "vault-cube-test" --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium /path/to/vault-cube-desktop-packages.iso --forceunmount
```

### 4b. Install desktop (in VM)

```bash
sudo mkdir -p /mnt/desktop
sudo mount /dev/cdrom /mnt/desktop
sudo bash /mnt/desktop/install-desktop-offline.sh /mnt/desktop
sudo reboot
```

**Note:** The install script takes 5-15 minutes depending on hardware.

---

## Phase 5: Login to GNOME Desktop

1. GDM (GNOME Display Manager) login screen appears
2. Click your username (`vaultadmin`)
3. **Important:** Click the gear/cog icon (bottom right) and select **"Ubuntu on Xorg"**
4. Enter password: `vaultadmin`
5. GNOME desktop loads

---

## Troubleshooting

### Black screen after login
- Press `Ctrl+Alt+F2` for text console
- Login and run: `sudo systemctl restart gdm3`

### No GUI after reboot
```bash
sudo systemctl set-default graphical.target
sudo systemctl start gdm3
```

### Mount shows "read-only" warning
- This is normal for ISO images - install will work fine

### "SATA link down" messages during boot
- Normal - system checking empty SATA ports

### Guest Additions build fails
- Ensure build tools installed: `sudo apt-get install -y build-essential linux-headers-$(uname -r)`

---

## Cleanup (on host)

```bash
# Stop and delete VM
VBoxManage controlvm "vault-cube-test" poweroff
VBoxManage unregistervm "vault-cube-test" --delete
```

---

## File Locations

| File | Description |
|------|-------------|
| `output/vault-cube-24.04-autoinstall.iso` | Base server autoinstall ISO |
| `output/vault-cube-desktop-packages.iso` | Offline desktop packages ISO |
| `scripts/install-desktop-offline.sh` | Desktop install script (included in ISO) |

---

Generated for Vault AI Systems - Vault Cube Golden Image
