# Packer Build Troubleshooting - Ubuntu 22.04

## Issue 0: Manual Installer Prompts (SOLVED - 2025-10-30)

**Problem:** Ubuntu installer shows GUI prompts for language, keyboard, installation confirmation instead of automated installation.

**Root Causes:**
1. **Incomplete password hash** in user-data (truncated to "$6$QCEX4M2tl7U$" - missing 90+ characters!)
2. **Wrong boot command** for Ubuntu 22.04 (used 24.04 GRUB command-line approach)
3. Boot command not properly triggering autoinstall mode

**Fixes Applied:**

### Fix 1: Complete Password Hash (CRITICAL)
**Before:** `password: "$6$QCEX4M2tl7U$"`
**After:** `password: "$6$rounds=656000$rGzgtCEONmiYotJd$JUACpbvUX5Ur7FgAhHuwzdJvxX9KgYU8cDd/AqS6od9bXCaj1In.uqKO6ow7rTyMkk37Dz1maBPybZrEjrGKu1"`

Generated with: `python3 -c "import crypt; print(crypt.crypt('vaultadmin', '\$6\$rounds=656000\$'))"`

### Fix 2: Corrected Boot Command for Ubuntu 22.04
Ubuntu 22.04 uses GRUB menu (not command-line) by default:

```hcl
boot_wait = "5s"
boot_command = [
  "<wait>",              # Wait for GRUB menu
  "e<wait>",             # Edit boot entry
  "<down><down><down>",  # Navigate to linux line
  "<end>",               # Go to end of line
  " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
  "<f10>"                # Boot with modified parameters
]
```

**Key Differences from 24.04:**
- 22.04: Uses GRUB menu → Edit entry with 'e' → Modify linux line → F10 to boot
- 24.04: Uses GRUB command-line → Type commands manually → 'boot' to start

### Fix 3: HTTP Server Verification
Packer automatically starts HTTP server on http://{{ .HTTPIP }}:{{ .HTTPPort }}/
- Serves files from `packer/http/` directory
- `user-data` = autoinstall configuration (cloud-init)
- `meta-data` = instance metadata (hostname, ID)

**Verification:**
```bash
# During build, check Packer output for:
# "Creating http server on port 8000"
# "Serving HTTP content from http directory"
```

## Issue 1: SSH Timeout (Solved)

**Problem:** Build failed after 31 minutes with "Timeout waiting for SSH"

**Root Causes:**
1. Complex user-data configuration
2. SSH timeout too short (30 minutes)
3. SSH service not properly enabled in late-commands

**Fixes Applied:**

### Fix 1: Simplified user-data
- Removed complex package list (will install via Ansible)
- Simplified network configuration (match any `en*` interface)
- Added explicit SSH service enable commands
- Added explicit SSH configuration in late-commands
- Used simpler LVM storage layout

### Fix 2: Increased SSH Timeouts
- `ssh_timeout`: 30m → 45m
- `ssh_handshake_attempts`: 20 → 50
- Added `ssh_pty = true` for better compatibility
- Added `ssh_wait_timeout = 45m`

### Fix 3: SSH Configuration in Late Commands
Added explicit commands to:
- Enable both `ssh` and `sshd` services
- Configure PasswordAuthentication = yes
- Set proper home directory permissions

## Debugging Methods

### 1. Standard Build with Logging (Recommended)
```bash
# Use official PACKER_LOG_PATH for logging
export PACKER_LOG=1
export PACKER_LOG_PATH=./packer-build.log
packer build ubuntu-24.04-demo-box.pkr.hcl

# OR with specific log level (TRACE is most verbose)
PACKER_LOG=TRACE PACKER_LOG_PATH=./packer-debug.log \
  packer build ubuntu-24.04-demo-box.pkr.hcl
```

### 2. Interactive Debug Mode (Step-by-Step)
```bash
# Pauses between each step for inspection
# Press Enter to continue after each step
packer build -debug ubuntu-24.04-demo-box.pkr.hcl
```

### 3. Error Handling Options
```bash
# Ask what to do when errors occur (interactive)
packer build -on-error=ask ubuntu-24.04-demo-box.pkr.hcl

# Cleanup and abort on error (default behavior)
packer build -on-error=cleanup ubuntu-24.04-demo-box.pkr.hcl

# Run cleanup provisioner before aborting
packer build -on-error=run-cleanup-provisioner ubuntu-24.04-demo-box.pkr.hcl
```

### 4. Template Inspection (Pre-Build Analysis)
```bash
# Inspect template without building
packer inspect ubuntu-24.04-demo-box.pkr.hcl

# Shows: variables, sources, provisioners, post-processors
```

### 5. Combined Debugging (Full Troubleshooting)
```bash
# Maximum debugging: TRACE logs + interactive + error handling
PACKER_LOG=TRACE PACKER_LOG_PATH=./packer-debug.log \
  packer build -debug -on-error=ask ubuntu-24.04-demo-box.pkr.hcl
```

**Log Levels** (from least to most verbose):
- `ERROR` - Only errors
- `WARN` - Warnings and errors
- `INFO` - General information
- `DEBUG` - Debugging information
- `TRACE` - Most verbose, includes all details

## How to Test

```bash
cd packer

# Option 1: Regular build
packer build ubuntu-24.04-demo-box.pkr.hcl

# Option 2: Build with logging (recommended - official HashiCorp method)
PACKER_LOG=1 PACKER_LOG_PATH=./packer-build.log \
  packer build ubuntu-24.04-demo-box.pkr.hcl

# Option 3: Interactive debug mode (step-by-step execution)
packer build -debug ubuntu-24.04-demo-box.pkr.hcl

# Option 4: Full debugging (TRACE logs + interactive + error prompts)
PACKER_LOG=TRACE PACKER_LOG_PATH=./packer-debug.log \
  packer build -debug -on-error=ask ubuntu-24.04-demo-box.pkr.hcl
```

## What to Watch For

### Good Signs:
- CPU usage 80-99% = system is working
- VirtualBox console shows text scrolling
- After ~15 minutes: "Waiting for SSH" message appears
- After ~20-25 minutes: "Connected to SSH!" appears

### Bad Signs:
- No CPU activity for 5+ minutes
- Console frozen (no cursor movement)
- "Timeout waiting for SSH" after 45 minutes

## If It Fails Again

1. **Check VirtualBox console** - Can you log in with `vaultadmin/vaultadmin`?

2. **If login works**, check SSH status:
   ```bash
   sudo systemctl status ssh
   ip addr show
   ```

3. **If login doesn't work**, the password hash might be wrong. We may need to regenerate it.

4. **Check cloud-init logs**:
   ```bash
   cloud-init status --long
   journalctl -u cloud-init -n 100
   ```

## Expected Timeline

- Minutes 0-15: Ubuntu installation
- Minutes 15-20: Cloud-init configuration
- Minutes 20-25: SSH service starts, Packer connects
- Minutes 25-30: Ansible provisioning (system updates, packages)
- Minutes 30-35: Cleanup and export

**Total: 30-35 minutes**
