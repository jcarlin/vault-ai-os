# Security Role

Comprehensive security hardening role for Vault Cube golden image (Epic 1a - Demo Box Operation).

## Overview

This role implements enterprise-grade security hardening including:
- **SSH Hardening** - Key-based authentication, modern cryptography, access controls
- **UFW Firewall** - Default-deny incoming policy with selective service access
- **fail2ban** - Intrusion prevention for SSH brute-force attacks
- **Automatic Security Updates** - Unattended security patch installation
- **Sysctl Hardening** - Kernel-level security improvements

## Requirements

- Ubuntu 24.04 LTS (Noble Numbat)
- Ansible 2.15+
- Sudo/root access on target system
- At least one SSH public key configured in `group_vars/all.yml`

## Role Variables

### SSH Configuration

Located in `defaults/main.yml`:

```yaml
ssh_port: 22                          # SSH port (change to 2222 for non-standard)
ssh_permit_root_login: no             # Disable root login (recommended)
ssh_password_authentication: no       # Disable password auth (recommended)
ssh_pubkey_authentication: yes        # Enable public key authentication
ssh_allow_users:                      # Allowed user accounts
  - vaultadmin
ssh_x11_forwarding: no                # Disable X11 forwarding
ssh_client_alive_interval: 300        # Timeout interval (5 minutes)
ssh_max_auth_tries: 3                 # Maximum authentication attempts
```

### UFW Firewall Configuration

```yaml
ufw_enable: true                      # Enable UFW firewall
ufw_default_incoming_policy: deny     # Default deny incoming
ufw_default_outgoing_policy: allow    # Default allow outgoing

ufw_allow_rules:                      # Services to allow
  - { port: 22, proto: tcp, comment: "SSH access" }
  - { port: 80, proto: tcp, comment: "HTTP for future services" }
  - { port: 443, proto: tcp, comment: "HTTPS for future services" }
```

### fail2ban Configuration

```yaml
fail2ban_enable: true                 # Enable fail2ban
fail2ban_bantime: 3600                # Ban duration (1 hour)
fail2ban_findtime: 600                # Detection window (10 minutes)
fail2ban_maxretry: 5                  # Max failed attempts before ban
fail2ban_banaction: ufw               # Use UFW for banning
```

### Automatic Updates Configuration

```yaml
unattended_upgrades_enable: true              # Enable automatic updates
unattended_upgrades_auto_reboot: false        # Don't auto-reboot (GPU workloads!)
unattended_upgrades_auto_reboot_time: "03:00" # Reboot time if enabled
```

**Important:** The following packages are **blacklisted** from automatic updates:
- NVIDIA drivers (`nvidia-driver-*`, `cuda-*`)
- Docker (`docker-ce`, `containerd.io`)
- Kernel updates (`linux-image-*`)

These require manual validation to ensure GPU workload stability.

### Security Hardening Options

```yaml
disable_ipv6: false                   # Set true to disable IPv6
enable_sysctl_hardening: true         # Apply kernel security settings
```

## Dependencies

This role should run after the `users` role to ensure the `vaultadmin` user exists.

**Role Execution Order in `site.yml`:**
1. `common` - Base system configuration
2. `users` - User account creation
3. **`security`** - Security hardening (this role)
4. `packages` - Package installation
5. `networking` - Network configuration

## Example Playbook

```yaml
---
- name: Configure Vault Cube with Security Hardening
  hosts: all
  become: true

  roles:
    - role: security
      tags: ['security', 'hardening']
```

## Running the Role

### Full Security Hardening

```bash
# Run complete security hardening
ansible-playbook -i inventory/local playbooks/site.yml --tags security
```

### Selective Execution

```bash
# Run only SSH hardening
ansible-playbook -i inventory/local playbooks/site.yml --tags security --skip-tags firewall,fail2ban

# Run only firewall configuration
ansible-playbook -i inventory/local playbooks/site.yml --tags security,firewall
```

## Security Features

### 1. SSH Hardening

**Implemented Controls:**
- ✅ Key-based authentication only (passwords disabled)
- ✅ Root login disabled
- ✅ Modern cryptography (ChaCha20-Poly1305, AES-256-GCM)
- ✅ User access controls (AllowUsers directive)
- ✅ Session timeout (5-minute idle timeout)
- ✅ Login banner with legal warning
- ✅ X11 forwarding disabled
- ✅ Agent/TCP forwarding disabled

**Validation:**

```bash
# Verify SSH configuration
sudo sshd -t

# Check SSH listening port
sudo ss -tlnp | grep ssh

# View active SSH connections
sudo who
```

### 2. UFW Firewall

**Default Policy:**
- Incoming: **DENY** (default-deny security model)
- Outgoing: **ALLOW** (permit all outbound)
- Forwarding: **DENY** (no IP forwarding)

**Allowed Services:**
- TCP/22 or TCP/2222 - SSH access
- TCP/80 - HTTP (for future Grafana/web services)
- TCP/443 - HTTPS (for future services)

**Validation:**

```bash
# Check firewall status
sudo ufw status verbose

# View firewall logs
sudo tail -f /var/log/ufw.log

# Test SSH access
ssh -p 22 vaultadmin@vault-cube-demo
```

### 3. fail2ban

**Protection:**
- Monitors `/var/log/auth.log` for SSH login failures
- Bans IP addresses after 5 failed attempts in 10 minutes
- Ban duration: 1 hour (configurable)
- Uses UFW for IP blocking

**Validation:**

```bash
# Check fail2ban status
sudo fail2ban-client status

# View SSH jail status
sudo fail2ban-client status sshd

# View banned IPs
sudo fail2ban-client get sshd banned

# Unban an IP manually
sudo fail2ban-client set sshd unbanip 192.168.1.100
```

### 4. Automatic Security Updates

**Update Policy:**
- Security updates: **Auto-install** daily
- Other updates: Manual review required
- Kernel updates: **Blacklisted** (require manual validation)
- NVIDIA drivers: **Blacklisted** (require GPU testing)
- Docker updates: **Blacklisted** (require workload testing)

**Validation:**

```bash
# Check unattended-upgrades status
sudo systemctl status unattended-upgrades

# View update logs
sudo tail -f /var/log/unattended-upgrades/unattended-upgrades.log

# Manually trigger update check
sudo unattended-upgrade --dry-run --debug
```

### 5. Sysctl Security Hardening

**Applied Settings:**
- IP spoofing protection
- ICMP redirect blocking
- SYN cookie protection (SYN flood mitigation)
- Broadcast ping blocking
- Source routing disabled
- Martian packet logging
- TCP timestamp fingerprinting disabled
- Optimized TCP buffers for high-performance networking

**Validation:**

```bash
# View all sysctl settings
sudo sysctl -a | grep -E "(net.ipv4|net.ipv6)"

# Check specific security setting
sudo sysctl net.ipv4.conf.all.rp_filter
```

## Idempotency

This role is fully idempotent and can be run multiple times safely:
- SSH configuration changes trigger service reload only if config changes
- UFW rules are configured declaratively
- fail2ban config updates trigger service restart only if changed
- Sysctl settings apply only if values differ

**Testing Idempotency:**

```bash
# Run 3 times - should show "changed=0" on runs 2 and 3
ansible-playbook -i inventory/local playbooks/site.yml --tags security
ansible-playbook -i inventory/local playbooks/site.yml --tags security
ansible-playbook -i inventory/local playbooks/site.yml --tags security
```

## Troubleshooting

### SSH Access Locked Out

If you lose SSH access after applying this role:

1. **Boot into recovery mode** (physical/console access required)
2. Check SSH configuration:
   ```bash
   sudo nano /etc/ssh/sshd_config
   # Temporarily enable password auth:
   PasswordAuthentication yes
   sudo systemctl restart ssh
   ```

3. Add your SSH public key:
   ```bash
   sudo nano /home/vaultadmin/.ssh/authorized_keys
   # Paste your public key
   ```

4. Re-disable password auth and restart SSH

### UFW Blocking Required Service

```bash
# Add custom rule
sudo ufw allow 3000/tcp comment "Custom service"

# Reload UFW
sudo ufw reload

# Verify rule added
sudo ufw status numbered
```

### fail2ban Banning Legitimate IP

```bash
# Unban IP address
sudo fail2ban-client set sshd unbanip 192.168.1.50

# Whitelist IP permanently
sudo nano /etc/fail2ban/jail.local
# Add under [DEFAULT]:
ignoreip = 127.0.0.1/8 ::1 192.168.1.50

# Restart fail2ban
sudo systemctl restart fail2ban
```

### Automatic Updates Breaking System

```bash
# Disable automatic updates temporarily
sudo systemctl stop unattended-upgrades
sudo systemctl disable unattended-upgrades

# Review recent updates
cat /var/log/apt/history.log

# Roll back problematic package
sudo apt-get install package-name=old-version
```

## Security Validation Checklist

After applying this role, verify:

- [ ] SSH access works with public key (no password prompt)
- [ ] Root login disabled (`ssh root@host` fails)
- [ ] UFW firewall enabled (`sudo ufw status` shows "active")
- [ ] fail2ban running (`sudo systemctl status fail2ban`)
- [ ] Automatic updates configured (`cat /etc/apt/apt.conf.d/20auto-upgrades`)
- [ ] SSH banner displayed on login
- [ ] Non-standard SSH port accessible (if changed)
- [ ] Firewall blocks unauthorized ports (`telnet host 3306` fails)

## Known Issues

### Issue 1: SSH Port Change Requires Coordination

**Problem:** Changing `ssh_port` from 22 to 2222 can lock you out if UFW rule doesn't update first.

**Mitigation:** The role allows port 22 through UFW **before** changing sshd_config, then reloads SSH.

### Issue 2: NVIDIA Driver Updates May Break GPU Workloads

**Problem:** Automatic updates could install incompatible NVIDIA drivers.

**Mitigation:** NVIDIA packages are blacklisted in `50unattended-upgrades.j2`. Drivers require manual testing.

### Issue 3: Kernel Updates Require Reboot

**Problem:** Security kernel updates need system reboot, disrupting GPU workloads.

**Mitigation:**
- Kernel updates blacklisted by default
- `unattended_upgrades_auto_reboot: false` prevents automatic reboots
- Schedule manual kernel updates during maintenance windows

## Epic 1a Context

**Task:** 1a.5 - Ansible Playbook - Basic Security
**Effort:** 4-6 hours
**Status:** ✅ COMPLETE
**Dependencies:** Task 1a.4 (Base System Configuration)

**Next Tasks:**
- Task 1a.6: Docker Installation
- Task 1a.7: Python Environment
- Task 1a.8: NVIDIA Drivers + CUDA (GPU hardware required)

## License

Proprietary - Vault AI Systems

## Author

Vault AI Systems Engineering Team
Contact: engineering@vault-ai-systems.com (placeholder)

---

**Last Updated:** 2025-10-30
**Role Version:** 1.0.0
**Tested On:** Ubuntu 24.04 LTS (Noble Numbat)
