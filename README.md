# Vault Cube Golden Image

Automated golden image creation for Vault AI Systems Cube workstation platform.

## Project Overview

This repository contains Packer templates and Ansible playbooks for building production-ready golden images for the Vault Cube AI workstation featuring:
- 4× NVIDIA RTX 5090 GPUs
- AMD Threadripper PRO 7975WX (32-core/64-thread)
- 256GB DDR5 ECC RAM
- Ubuntu 22.04 LTS

## Current Status

**Phase:** Epic 1a - Demo Box Operation (Foundation)
**Progress:** Week 1 - Packer + Ansible Base System Complete

**Completed:**
- ✅ Task 1a.1: Development environment setup
- ✅ Task 1a.2: Git repository structure
- ✅ Task 1a.3: Packer template (builds .ova successfully)
- ✅ Task 1a.4: Ansible base system (common, users, packages, networking)
- ✅ Task 1a.5: Ansible security hardening (SSH, UFW, fail2ban, auto-updates)

**Next:**
- 📋 Task 1a.6: Docker installation
- 📋 Task 1a.7: Python environment
- ⏸️ Task 1a.8+: NVIDIA drivers (blocked until GPU hardware arrives)

## Repository Structure

```
.
├── packer/              # Packer templates for image building
│   ├── ubuntu-22.04-demo-box.pkr.hcl    # Main Packer template
│   ├── http/                             # Cloud-init autoinstall files
│   └── output-*/                         # Build artifacts (.ova files)
├── ansible/             # Ansible playbooks and roles
│   ├── playbooks/
│   │   └── site.yml                      # Master playbook
│   ├── roles/
│   │   ├── common/                       # Base system config
│   │   ├── users/                        # User management
│   │   ├── security/                     # SSH/firewall/fail2ban
│   │   ├── packages/                     # Package installation
│   │   └── networking/                   # Network configuration
│   ├── group_vars/
│   │   └── all.yml                       # Global variables
│   └── inventory/                        # Inventory files
├── scripts/             # Validation and utility scripts
├── tests/               # Test scripts and validation
└── docs/                # Documentation
    ├── epic-1a-demo-box.md               # Current epic documentation
    └── epic-1b-production-hardening.md   # Next phase
```

## Prerequisites

### Required Software

- **Packer:** 1.14.2+ ([Download](https://www.packer.io/downloads))
- **Ansible:** 2.19.3+ (Install: `brew install ansible` on macOS)
- **VirtualBox:** 7.0+ ([Download](https://www.virtualbox.org/))
- **VBoxManage:** Included with VirtualBox

### System Requirements

- **RAM:** 8GB minimum for VM testing (16GB recommended)
- **Disk:** 100GB free space for builds and artifacts
- **CPU:** 4 cores minimum (for VM allocation)

### Required Files

- **Ubuntu 22.04.5 LTS ISO:** [Download](https://releases.ubuntu.com/22.04/)
  - Place in: `/Users/julian/Downloads/ubuntu-22.04.5-live-server-amd64.iso`
  - Or update `iso_url` variable in Packer template

---

## Quick Start

### 1. Build Golden Image with Packer

```bash
# Navigate to packer directory
cd packer

# Validate Packer template
packer validate ubuntu-22.04-demo-box.pkr.hcl

# Build the image (headless=false shows VirtualBox GUI)
packer build ubuntu-22.04-demo-box.pkr.hcl

# Build time: ~20-30 minutes
# Output: packer/output-vault-cube-demo-box/vault-cube-demo-box.ova
```

**What Packer does:**
1. Creates VirtualBox VM (4 CPU, 8GB RAM, 50GB disk)
2. Boots Ubuntu 22.04 ISO with autoinstall (cloud-init)
3. Installs base Ubuntu system
4. Runs provisioners (system updates, cleanup)
5. Exports .ova file

**Note:** Ansible provisioning is currently disabled in Packer (lines 193-214 commented out). See "Testing Ansible" section below to test roles before enabling in Packer.

### 2. Import and Test the Built Image

```bash
# Import .ova into VirtualBox
VBoxManage import packer/output-vault-cube-demo-box/vault-cube-demo-box.ova

# Start the VM
VBoxManage startvm vault-cube-demo-box

# Or use VirtualBox GUI:
# 1. Open VirtualBox
# 2. File → Import Appliance
# 3. Select the .ova file
# 4. Click Import and Start
```

**Default credentials:**
- Username: `vaultadmin`
- Password: `vaultadmin`

**Login via VirtualBox console window** (no SSH setup needed for testing)

---

## Testing Ansible Roles

Before enabling Ansible in Packer, test roles manually for faster iteration.

### Method 1: Shared Folder (Recommended)

**Advantages:**
- ✅ No file copying needed
- ✅ Edit on Mac, run in VM instantly
- ✅ Perfect for development iteration

**Steps:**

```bash
# 1. Power off VM if running
VBoxManage controlvm vault-cube-demo-box poweroff

# 2. Create shared folder pointing to your ansible directory
VBoxManage sharedfolder add vault-cube-demo-box \
  --name ansible-files \
  --hostpath /Users/julian/dev/vault-ai-systems/cube-golden-image/ansible \
  --automount \
  --auto-mount-point /mnt/ansible

# 3. Start VM
VBoxManage startvm vault-cube-demo-box

# 4. Login to VM (vaultadmin/vaultadmin) and run:
sudo apt-get update
sudo apt-get install -y virtualbox-guest-utils ansible build-essential dkms linux-headers-$(uname -r)
sudo usermod -a -G vboxsf vaultadmin
sudo reboot

# 5. After reboot, verify shared folder
ls -la /mnt/ansible
# Should show: playbooks/, roles/, group_vars/

# 6. Run Ansible playbook
cd /mnt/ansible
ansible-playbook -i localhost, -c local playbooks/site.yml

# 7. Verify security hardening
sudo ufw status verbose        # Should show firewall active
sudo systemctl status fail2ban # Should show fail2ban running
cat /etc/ssh/banner           # Should show Vault Cube banner
```

### Method 2: Direct Git Clone (Alternative)

```bash
# Inside VM, install git and ansible
sudo apt-get update
sudo apt-get install -y git ansible

# Clone repository (if on GitHub)
git clone https://github.com/vault-ai-systems/cube-golden-image.git
cd cube-golden-image/ansible

# Run Ansible
ansible-playbook -i localhost, -c local playbooks/site.yml
```

### Ansible Testing Commands

```bash
# Syntax check (no VM required)
ansible-playbook playbooks/site.yml --syntax-check

# List all tasks
ansible-playbook playbooks/site.yml --list-tasks

# Dry-run (check mode)
ansible-playbook -i localhost, -c local playbooks/site.yml --check

# Run specific role only
ansible-playbook -i localhost, -c local playbooks/site.yml --tags security

# Run with verbose output
ansible-playbook -i localhost, -c local playbooks/site.yml -vv
```

---

## Enabling Ansible in Packer

Once Ansible roles work correctly, enable in Packer for automated builds:

**Edit `packer/ubuntu-22.04-demo-box.pkr.hcl`:**

```hcl
# UNCOMMENT lines 193-200: Install Ansible prerequisites
provisioner "shell" {
  inline = [
    "echo 'Installing Python and Ansible prerequisites...'",
    "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-apt",
    "echo 'Prerequisites installed!'"
  ]
}

# UNCOMMENT and UPDATE lines 202-214: Ansible provisioning
provisioner "ansible-local" {
  playbook_file   = "../ansible/playbooks/site.yml"
  role_paths      = [
    "../ansible/roles/common",
    "../ansible/roles/users",
    "../ansible/roles/security",    # ADD THIS LINE
    "../ansible/roles/packages",
    "../ansible/roles/networking"
  ]
  staging_directory = "/tmp/ansible"
  extra_arguments = [
    "--extra-vars", "ansible_python_interpreter=/usr/bin/python3"
  ]
}
```

Then rebuild:

```bash
cd packer
packer build ubuntu-22.04-demo-box.pkr.hcl
```

---

## VBoxManage Quick Reference

### VM Management

```bash
# List all VMs
VBoxManage list vms

# Show VM info
VBoxManage showvminfo vault-cube-demo-box

# Start VM (GUI window)
VBoxManage startvm vault-cube-demo-box

# Start VM (headless, no GUI)
VBoxManage startvm vault-cube-demo-box --type headless

# Power off VM (graceful)
VBoxManage controlvm vault-cube-demo-box poweroff

# Save VM state (suspend)
VBoxManage controlvm vault-cube-demo-box savestate

# Delete VM and files
VBoxManage unregistervm vault-cube-demo-box --delete
```

### Shared Folders

```bash
# Add shared folder
VBoxManage sharedfolder add vault-cube-demo-box \
  --name my-folder \
  --hostpath /path/on/host \
  --automount \
  --auto-mount-point /mnt/my-folder

# Remove shared folder
VBoxManage sharedfolder remove vault-cube-demo-box --name my-folder

# List shared folders
VBoxManage showvminfo vault-cube-demo-box | grep "Shared folders"
```

### Snapshots

```bash
# Create snapshot
VBoxManage snapshot vault-cube-demo-box take "clean-state" \
  --description "Before Ansible testing"

# List snapshots
VBoxManage snapshot vault-cube-demo-box list

# Restore snapshot
VBoxManage snapshot vault-cube-demo-box restore "clean-state"

# Delete snapshot
VBoxManage snapshot vault-cube-demo-box delete "clean-state"
```

### Networking (Advanced)

```bash
# Add port forwarding (SSH example - DEV ONLY, not for production)
VBoxManage controlvm vault-cube-demo-box natpf1 "ssh,tcp,,2222,,22"

# Remove port forwarding
VBoxManage controlvm vault-cube-demo-box natpf1 delete ssh

# Show network config
VBoxManage showvminfo vault-cube-demo-box | grep NIC
```

---

## Development Workflow

### Recommended Iteration Cycle

**Fast Iteration (Ansible changes):**
1. Edit Ansible roles on your Mac
2. Boot VM with shared folder
3. Run ansible-playbook inside VM
4. Test changes immediately
5. Repeat steps 2-4 until working

**Full Build (final validation):**
1. Enable Ansible in Packer template
2. Run `packer build`
3. Test resulting .ova
4. Commit to git

### Best Practices

- ✅ **Test Ansible manually first** - Faster feedback than rebuilding Packer
- ✅ **Use VirtualBox snapshots** - Save clean states before testing
- ✅ **Run Ansible idempotency tests** - Playbook should work when run 3x times
- ✅ **Check syntax before building** - `packer validate` and `ansible-playbook --syntax-check`
- ❌ **Don't add dev configs to Packer** - SSH port forwarding, etc. are runtime-only

### Testing Checklist

Before marking a task complete:

```bash
# 1. Syntax validation
packer validate packer/ubuntu-22.04-demo-box.pkr.hcl
ansible-playbook ansible/playbooks/site.yml --syntax-check

# 2. Test Ansible manually (in VM)
ansible-playbook -i localhost, -c local /mnt/ansible/playbooks/site.yml

# 3. Verify idempotency (run 3x times, should show 0 changes on runs 2-3)
ansible-playbook -i localhost, -c local /mnt/ansible/playbooks/site.yml
ansible-playbook -i localhost, -c local /mnt/ansible/playbooks/site.yml
ansible-playbook -i localhost, -c local /mnt/ansible/playbooks/site.yml

# 4. Full Packer build
cd packer && packer build ubuntu-22.04-demo-box.pkr.hcl

# 5. Import and test final .ova
VBoxManage import packer/output-vault-cube-demo-box/vault-cube-demo-box.ova
VBoxManage startvm vault-cube-demo-box
# Verify all features work as expected
```

---

## Troubleshooting

### Packer build fails during cloud-init

**Problem:** Ubuntu installer doesn't start autoinstall

**Solution:**
- Check `packer/http/user-data` syntax
- Verify HTTP server is accessible (check Packer output)
- Increase `boot_wait` in Packer template

### Ansible fails with "Permission denied"

**Problem:** Shared folder not accessible

**Solution:**
```bash
# Ensure user is in vboxsf group
sudo usermod -a -G vboxsf vaultadmin
sudo reboot

# Or mount manually
sudo mount -t vboxsf ansible-files /mnt/ansible
```

### VirtualBox Guest Additions won't install

**Problem:** Missing kernel headers

**Solution:**
```bash
sudo apt-get update
sudo apt-get install -y build-essential dkms linux-headers-$(uname -r)
sudo apt-get install -y virtualbox-guest-utils virtualbox-guest-dkms
```

### Packer SSH timeout

**Problem:** Packer can't connect via SSH after installation

**Solution:**
- Check SSH service is running in VM console: `systemctl status ssh`
- Verify user exists: `cat /etc/passwd | grep vaultadmin`
- Check cloud-init logs: `sudo cat /var/log/cloud-init.log`

---

## Documentation

- [Epic 1a - Demo Box](docs/epic-1a-demo-box.md) - Current phase detailed tasks
- [Epic 1b - Production Hardening](docs/epic-1b-production-hardening.md) - Next phase
- [Security Role README](ansible/roles/security/README.md) - Security hardening details
- [CLAUDE.md](CLAUDE.md) - Claude Code configuration and SPARC workflow

## Support

- **Issues:** Create GitHub issue with detailed description
- **Documentation:** See `docs/` directory
- **Epic Progress:** Track in `docs/epic-1a-demo-box.md`

## License

Proprietary - Vault AI Systems

---

**Last Updated:** 2025-10-30
**Epic:** 1a - Demo Box Operation (Week 1 Complete)
