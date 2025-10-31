# Ubuntu 22.04 Autoinstall Validation Guide

## What is Autoinstall?

**Autoinstall** is Ubuntu's automated installation system (introduced in Ubuntu 20.04) that uses **cloud-init** to perform unattended installations. When properly configured, the installer should:

✅ Skip all interactive prompts (language, keyboard, partitioning, user creation)
✅ Use configuration from `user-data` file served via HTTP
✅ Complete installation automatically
✅ Reboot and start SSH service for Packer to connect

## How Autoinstall Works

### 1. Boot Process with Autoinstall Trigger

**GRUB Boot Command:**
```hcl
boot_command = [
  "<wait>",              # Wait for GRUB menu to appear
  "e<wait>",             # Press 'e' to edit boot entry
  "<down><down><down>",  # Navigate to linux kernel line
  "<end>",               # Go to end of line
  " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
  "<f10>"                # Boot with modified kernel parameters
]
```

**Kernel Parameters Explained:**
- `autoinstall` - Tells Ubuntu installer to use automated installation mode
- `ds=nocloud-net` - Specifies cloud-init data source type (NoCloud Network)
- `s=http://10.0.2.2:8000/` - URL where cloud-init config files are served (Packer HTTP server)

### 2. Cloud-Init Data Source (NoCloud)

Packer starts an HTTP server serving files from `packer/http/` directory:

**Required Files:**
- `user-data` - Main autoinstall configuration (YAML with `#cloud-config` header)
- `meta-data` - Instance metadata (hostname, instance-id)

**HTTP Server URL Construction:**
- `{{ .HTTPIP }}` - Packer variable for HTTP server IP (typically 10.0.2.2 for NAT)
- `{{ .HTTPPort }}` - Packer variable for HTTP server port (typically 8000-9000)

### 3. Autoinstall Configuration Structure

**File: `/Users/julian/dev/vault-ai-systems/cube-golden-image/packer/http/user-data`**

```yaml
#cloud-config
autoinstall:
  version: 1

  # User created BEFORE SSH service starts (critical for Packer SSH connection)
  identity:
    hostname: vault-cube-demo
    username: vaultadmin
    password: "$6$rounds=656000$..." # SHA-512 hash (NOT plaintext!)

  locale: en_US.UTF-8
  keyboard:
    layout: us

  network:
    version: 2
    ethernets:
      default:
        match:
          name: "e*"  # Matches en*, eth*, enp*, ens*
        dhcp4: true

  storage:
    layout:
      name: lvm  # Uses logical volume manager

  ssh:
    install-server: true
    allow-pw: true  # Allow password authentication

  packages:
    - openssh-server
    - python3-apt

  late-commands:
    # Commands run after installation, before first boot
    # Configure sudo, SSH, permissions
```

## Expected vs. Actual Behavior

### ✅ Expected Behavior (Correct Autoinstall)

**Timeline:**
1. **0:00-0:05** - GRUB appears, Packer sends boot command
2. **0:05-0:10** - Kernel boots with autoinstall parameters
3. **0:10-0:15** - Ubuntu installer downloads user-data/meta-data from Packer HTTP server
4. **0:15-5:00** - Automated installation (NO PROMPTS):
   - Partition disk with LVM
   - Install base system
   - Create user from identity section
   - Install packages (openssh-server, python3-apt)
   - Run late-commands (sudo config, SSH config)
5. **5:00-5:30** - System reboots automatically
6. **5:30-6:00** - SSH service starts, Packer connects
7. **6:00-25:00** - Packer runs provisioners (system updates, Ansible)
8. **25:00-30:00** - Cleanup and export OVA

**VirtualBox Console Output (Expected):**
```
[  OK  ] Started Ubuntu Live Installer
[  OK  ] Reached target Cloud-init target
[  OK  ] cloud-init: Retrieving http://10.0.2.2:8000/user-data
[  OK  ] cloud-init: Retrieving http://10.0.2.2:8000/meta-data
Running automated installation...
Partitioning disk...
Installing system...
Creating user vaultadmin...
Installing packages...
Configuring SSH...
Installation complete. Rebooting...
```

### ❌ Actual Behavior (Broken Autoinstall - Your Issue)

**Timeline:**
1. **0:00-0:05** - GRUB appears
2. **0:05-0:10** - Ubuntu installer starts
3. **0:10+** - **Interactive installer GUI appears** with prompts:
   - ❌ "Select your language"
   - ❌ "Choose keyboard layout"
   - ❌ "Confirm installation"
   - ❌ Waiting for user input (build stalls here)

**VirtualBox Console Output (Broken):**
```
Ubuntu Server 22.04 LTS Installer

┌──────────────────────────────┐
│ Welcome! Select your language│
│                              │
│ > English                    │
│   Español                    │
│   Français                   │
└──────────────────────────────┘

Press Enter to continue...
```

## Why Autoinstall Failed (Root Causes)

### Issue #1: Incomplete Password Hash (CRITICAL)

**Problem:** Password hash was truncated in user-data file.

**Broken Configuration:**
```yaml
identity:
  username: vaultadmin
  password: "$6$QCEX4M2tl7U$"  # ❌ Only 17 characters (should be 100+)
```

**Impact:**
- Cloud-init rejects invalid password hash
- User creation fails in identity section
- Autoinstall aborts and falls back to interactive installer

**Fix:**
```yaml
identity:
  username: vaultadmin
  password: "$6$rounds=656000$rGzgtCEONmiYotJd$JUACpbvUX5Ur7FgAhHuwzdJvxX9KgYU8cDd/AqS6od9bXCaj1In.uqKO6ow7rTyMkk37Dz1maBPybZrEjrGKu1"
```

**Generate Hash:**
```bash
python3 -c "import crypt; print(crypt.crypt('vaultadmin', '\$6\$rounds=656000\$'))"
```

### Issue #2: Wrong Boot Command for Ubuntu 22.04

**Problem:** Boot command was designed for Ubuntu 24.04, which uses different GRUB interface.

**Broken Boot Command (24.04 style):**
```hcl
boot_command = [
  "<esc><wait5>",      # ❌ Escape to GRUB command-line (24.04 only)
  "c<wait2>",          # ❌ Open GRUB command prompt (24.04 only)
  "linux /casper/vmlinuz autoinstall ...",
  "initrd /casper/initrd",
  "boot"
]
```

**Why This Fails on 22.04:**
- Ubuntu 22.04 boots directly to GRUB menu (not command-line)
- Pressing ESC + 'c' doesn't work reliably
- Timing issues with `<wait5>` on slower systems

**Fixed Boot Command (22.04 GRUB menu style):**
```hcl
boot_command = [
  "<wait>",              # ✅ Wait for GRUB menu
  "e<wait>",             # ✅ Edit default boot entry
  "<down><down><down>",  # ✅ Navigate to linux line
  "<end>",               # ✅ Go to end of line
  " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
  "<f10>"                # ✅ Boot with modifications
]
```

### Issue #3: Missing HTTP Server Validation

**Problem:** No verification that Packer HTTP server is accessible from VM.

**Packer HTTP Server Details:**
- Packer starts HTTP server automatically when `http_directory = "http"` is set
- Server listens on host machine (typically 10.0.2.2 for VirtualBox NAT)
- VM must be able to reach this IP during boot

**Validation During Build:**
```bash
# Look for these lines in Packer output:
virtualbox-iso.ubuntu-2204: Creating http server on port 8081
virtualbox-iso.ubuntu-2204: Serving HTTP content from packer/http
```

**Test HTTP Server Manually:**
```bash
# During build, from host machine:
curl http://127.0.0.1:8081/user-data
curl http://127.0.0.1:8081/meta-data

# Should return cloud-config files
```

## How to Verify Autoinstall is Working

### 1. Watch VirtualBox Console During Build

**Good Signs (Autoinstall Working):**
```
✅ No interactive prompts appear
✅ Text scrolls rapidly with installation progress
✅ CPU usage stays 80-100%
✅ You see: "cloud-init: Retrieving http://10.0.2.2:8081/user-data"
✅ You see: "Running automated installation..."
✅ System reboots automatically after 5-15 minutes
```

**Bad Signs (Autoinstall Failed):**
```
❌ GUI installer appears with language selection
❌ Cursor blinking, waiting for input
❌ CPU usage drops to <20%
❌ Build stalls for 5+ minutes with no progress
❌ No mention of cloud-init or autoinstall in logs
```

### 2. Check Packer Output for HTTP Server

**Expected Output:**
```
==> virtualbox-iso.ubuntu-2204: Creating http server on port 8081
==> virtualbox-iso.ubuntu-2204: Serving HTTP content from packer/http
==> virtualbox-iso.ubuntu-2204: Starting VirtualBox VM
==> virtualbox-iso.ubuntu-2204: Typing boot command...
==> virtualbox-iso.ubuntu-2204: Waiting for SSH to become available...
```

**Troubleshooting:**
```bash
# Enable verbose logging
export PACKER_LOG=1
export PACKER_LOG_PATH=./packer-autoinstall-debug.log
packer build ubuntu-22.04-demo-box.pkr.hcl

# Search logs for autoinstall evidence
grep -i "autoinstall" packer-autoinstall-debug.log
grep -i "cloud-init" packer-autoinstall-debug.log
grep -i "http" packer-autoinstall-debug.log
```

### 3. Manual Testing Inside VirtualBox Console

If build stalls at installer, you can test manually:

**Step 1: Check if autoinstall parameter was set**
```bash
# At GRUB menu, press 'e' to edit
# Check if you see: autoinstall ds=nocloud-net;s=http://10.0.2.2:8081/
# If NOT present, boot_command failed to inject parameters
```

**Step 2: Test HTTP server access from installer**
```bash
# Press Ctrl+Alt+F2 to get shell during installation
# Try to fetch cloud-init files:
curl http://10.0.2.2:8081/user-data
curl http://10.0.2.2:8081/meta-data

# If these fail, network/HTTP server issue
# If these succeed but autoinstall didn't work, config issue
```

### 4. Validate user-data Syntax

**Check YAML syntax:**
```bash
cd /Users/julian/dev/vault-ai-systems/cube-golden-image/packer

# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('http/user-data'))" && echo "✅ Valid YAML" || echo "❌ Invalid YAML"

# Check cloud-config format
cloud-init schema --config-file http/user-data
```

**Common Syntax Errors:**
```yaml
# ❌ WRONG: Missing colon
autoinstall
  version: 1

# ✅ CORRECT
autoinstall:
  version: 1

# ❌ WRONG: Incorrect indentation (tabs instead of spaces)
	identity:
	  username: admin

# ✅ CORRECT: 2 spaces per indent level
  identity:
    username: admin

# ❌ WRONG: Incomplete password hash
password: "$6$QCEX"

# ✅ CORRECT: Full SHA-512 hash (100+ characters)
password: "$6$rounds=656000$rGzgtCEONmiYotJd$JUACpbvUX5Ur7FgAhHuwzdJvxX9KgYU8cDd/AqS6od9bXCaj1In.uqKO6ow7rTyMkk37Dz1maBPybZrEjrGKu1"
```

## Testing the Fixed Configuration

### Step 1: Validate Files Before Build

```bash
cd /Users/julian/dev/vault-ai-systems/cube-golden-image/packer

# 1. Verify user-data has complete password hash
grep "password:" http/user-data
# Should show: password: "$6$rounds=656000$rGzgtCEONmiYotJd$..." (100+ chars)

# 2. Verify boot_command uses GRUB menu navigation (not command-line)
grep -A 8 "boot_command" ubuntu-22.04-demo-box.pkr.hcl
# Should see: "e<wait>", "<down><down><down>", "<f10>"

# 3. Verify HTTP directory is set
grep "http_directory" ubuntu-22.04-demo-box.pkr.hcl
# Should show: http_directory = "http"

# 4. Check Packer template syntax
packer validate ubuntu-22.04-demo-box.pkr.hcl
# Should show: "The configuration is valid."
```

### Step 2: Run Build with Logging

```bash
cd /Users/julian/dev/vault-ai-systems/cube-golden-image/packer

# Clean previous builds
rm -rf output-vault-cube-demo-box/
rm -f manifest.json packer-*.log

# Run build with full logging
export PACKER_LOG=1
export PACKER_LOG_PATH=./packer-build-$(date +%Y%m%d-%H%M%S).log
packer build ubuntu-22.04-demo-box.pkr.hcl
```

### Step 3: Watch VirtualBox Console

**Timeline to Watch:**

**0:00 - 0:30:** GRUB menu appears, Packer types boot command
- ✅ You should see the GRUB menu briefly
- ✅ Boot entry should be highlighted and automatically edited
- ✅ System boots without pausing

**0:30 - 1:00:** Kernel boots with autoinstall parameters
- ✅ Text scrolls with kernel messages
- ✅ You see: "Loading Linux kernel" and "Loading initial ramdisk"

**1:00 - 2:00:** Cloud-init fetches configuration
- ✅ You see: "cloud-init[XXX]: Retrieving http://10.0.2.2:XXXX/user-data"
- ✅ You see: "cloud-init[XXX]: Retrieving http://10.0.2.2:XXXX/meta-data"

**2:00 - 10:00:** Automated installation runs
- ✅ Text scrolls continuously (disk partitioning, package installation)
- ✅ CPU stays 80-100%
- ✅ NO interactive prompts appear
- ✅ You see: "Installing system", "Configuring packages"

**10:00 - 12:00:** System reboots
- ✅ You see: "Rebooting..." or "System halted"
- ✅ VM restarts automatically

**12:00 - 15:00:** First boot, SSH service starts
- ✅ You see: "cloud-init[XXX]: Cloud-init finished"
- ✅ Login prompt appears: "vault-cube-demo login:"

**15:00+:** Packer connects via SSH
- ✅ Packer output shows: "Connected to SSH!"
- ✅ Shell provisioners run (system update, Ansible)

**Total Time: 15-30 minutes**

### Step 4: Verify Success

**If build completes successfully:**
```bash
# Check output directory
ls -lh output-vault-cube-demo-box/
# Should contain: vault-cube-demo-box.ova (2-5 GB)

# Check manifest
cat manifest.json
# Should show build artifacts and checksums

# Import OVA into VirtualBox
VBoxManage import output-vault-cube-demo-box/vault-cube-demo-box.ova --vsys 0 --vmname "test-cube"

# Start and test
VBoxManage startvm "test-cube"

# Login with: vaultadmin / vaultadmin
# Test: sudo whoami (should show "root" without password prompt)
```

## Troubleshooting Checklist

If autoinstall still doesn't work, check each item:

- [ ] **Password hash is complete** (100+ characters, not truncated)
- [ ] **user-data has valid YAML syntax** (no tabs, proper indentation)
- [ ] **user-data starts with `#cloud-config`** (exact spelling, lowercase)
- [ ] **meta-data exists** in http/ directory (can be minimal)
- [ ] **boot_command uses GRUB menu navigation** (e, arrows, F10 - not command-line)
- [ ] **boot_command includes autoinstall parameter** (check for typos)
- [ ] **boot_command includes ds=nocloud-net parameter** (tells cloud-init where to fetch config)
- [ ] **HTTP server URL has trailing slash** (`s=http://...../` not `s=http://....`)
- [ ] **ISO checksum is correct** (9bc6028870aef3f74f4e16b900008179e78b130e6b0b9a140635434a46aa98b0)
- [ ] **VirtualBox NAT is configured** (first network adapter should be NAT)
- [ ] **Packer HTTP server starts** (check for "Creating http server" in output)
- [ ] **SSH credentials match user-data** (username: vaultadmin, password: vaultadmin)

## References

- **Ubuntu Autoinstall Documentation:** https://ubuntu.com/server/docs/install/autoinstall
- **Cloud-Init NoCloud:** https://cloudinit.readthedocs.io/en/latest/reference/datasources/nocloud.html
- **Packer VirtualBox Builder:** https://developer.hashicorp.com/packer/plugins/builders/virtualbox/iso
- **Packer Boot Commands:** https://developer.hashicorp.com/packer/docs/templates/hcl_templates/boot-command

## Summary: What Should Happen Now

After applying the fixes:

1. ✅ **Complete password hash** prevents identity creation failure
2. ✅ **Corrected boot command** properly triggers autoinstall on Ubuntu 22.04
3. ✅ **NO manual prompts** - installation is fully automated
4. ✅ **Packer connects via SSH** after installation completes
5. ✅ **Build finishes in 20-30 minutes** and produces OVA file

**Next Steps:**
```bash
# Run the fixed build
cd /Users/julian/dev/vault-ai-systems/cube-golden-image/packer
packer build ubuntu-22.04-demo-box.pkr.hcl

# Watch VirtualBox console - should see NO interactive prompts
# Wait 20-30 minutes for completion
# Result: output-vault-cube-demo-box/vault-cube-demo-box.ova
```
