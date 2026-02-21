#!/usr/bin/env bash
###############################################################################
# setup-ssh.sh — Idempotent SSH server install & configuration
#
# Safe to run multiple times. Will:
#   1. Install openssh-server if missing
#   2. Enable and start sshd
#   3. Open firewall port 22 (ufw / firewalld / iptables)
#   4. Harden basic settings (disable root login, disable password-less login)
#   5. Print connection info
#
# Usage:
#   chmod +x setup-ssh.sh && sudo ./setup-ssh.sh
#
# Supported: Ubuntu/Debian, RHEL/CentOS/Fedora, Arch
###############################################################################
set -euo pipefail

# ---------- helpers ----------------------------------------------------------
info()  { printf '\n\033[1;32m[INFO]\033[0m  %s\n' "$*"; }
warn()  { printf '\n\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
err()   { printf '\n\033[1;31m[ERROR]\033[0m %s\n' "$*"; exit 1; }

need_root() {
  if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root.  Try:  sudo $0"
  fi
}

# ---------- detect distro family --------------------------------------------
detect_distro() {
  if   command -v apt-get &>/dev/null; then DISTRO_FAMILY="debian"
  elif command -v dnf     &>/dev/null; then DISTRO_FAMILY="rhel"
  elif command -v yum     &>/dev/null; then DISTRO_FAMILY="rhel"
  elif command -v pacman  &>/dev/null; then DISTRO_FAMILY="arch"
  else err "Unsupported package manager. Install openssh-server manually."
  fi
  info "Detected distro family: $DISTRO_FAMILY"
}

# ---------- install openssh-server ------------------------------------------
install_ssh() {
  if command -v sshd &>/dev/null || systemctl list-unit-files sshd.service &>/dev/null 2>&1 || systemctl list-unit-files ssh.service &>/dev/null 2>&1; then
    info "openssh-server is already installed."
    return
  fi

  info "Installing openssh-server..."
  case "$DISTRO_FAMILY" in
    debian)
      # Try install first; only run apt-get update if package cache is stale/empty
      if ! apt-get install -y openssh-server 2>/dev/null; then
        info "Package cache miss — running apt-get update..."
        apt-get update -qq && apt-get install -y openssh-server
      fi
      ;;
    rhel)   dnf install -y openssh-server 2>/dev/null || yum install -y openssh-server ;;
    arch)   pacman -Sy --noconfirm openssh ;;
  esac
  info "openssh-server installed."
}

# ---------- enable & start sshd ---------------------------------------------
start_sshd() {
  # service name varies: 'ssh' on Debian/Ubuntu, 'sshd' on RHEL/Arch
  local svc=""
  if systemctl list-unit-files ssh.service &>/dev/null 2>&1; then
    svc="ssh"
  elif systemctl list-unit-files sshd.service &>/dev/null 2>&1; then
    svc="sshd"
  else
    err "Cannot find ssh or sshd systemd service."
  fi

  info "Enabling and starting $svc..."
  systemctl enable "$svc"
  systemctl start  "$svc" || systemctl restart "$svc"

  if systemctl is-active --quiet "$svc"; then
    info "$svc is running."
  else
    err "$svc failed to start. Check: journalctl -xeu $svc"
  fi
}

# ---------- open firewall port 22 -------------------------------------------
open_firewall() {
  # ufw (Ubuntu/Debian default)
  if command -v ufw &>/dev/null; then
    if ufw status | grep -q "Status: active"; then
      info "ufw is active — allowing SSH (port 22)..."
      ufw allow 22/tcp comment "SSH" >/dev/null
      info "ufw rule added."
    else
      info "ufw is installed but inactive — no rule needed."
    fi
    return
  fi

  # firewalld (RHEL/Fedora)
  if command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld; then
    info "firewalld is active — allowing SSH..."
    firewall-cmd --permanent --add-service=ssh >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null
    info "firewalld rule added."
    return
  fi

  # iptables fallback
  if command -v iptables &>/dev/null; then
    if ! iptables -C INPUT -p tcp --dport 22 -j ACCEPT &>/dev/null; then
      info "Adding iptables rule for port 22..."
      iptables -I INPUT -p tcp --dport 22 -j ACCEPT
      info "iptables rule added (non-persistent across reboots)."
    else
      info "iptables already allows port 22."
    fi
    return
  fi

  info "No firewall detected — port 22 should be open by default."
}

# ---------- basic hardening --------------------------------------------------
harden_sshd() {
  local conf="/etc/ssh/sshd_config"
  if [[ ! -f "$conf" ]]; then
    warn "$conf not found — skipping hardening."
    return
  fi

  # Backup original config (once)
  if [[ ! -f "${conf}.orig" ]]; then
    cp "$conf" "${conf}.orig"
    info "Backed up original sshd_config to ${conf}.orig"
  fi

  # Helper: set a key=value, or add it if missing
  set_sshd_opt() {
    local key="$1" val="$2"
    if grep -qE "^\s*${key}\s+" "$conf"; then
      # Key exists (possibly commented) — update it
      sed -i "s|^\s*#*\s*${key}\s.*|${key} ${val}|" "$conf"
    else
      echo "${key} ${val}" >> "$conf"
    fi
  }

  info "Applying SSH hardening (disable root login, enable password auth)..."
  set_sshd_opt "PermitRootLogin"        "no"
  set_sshd_opt "PermitEmptyPasswords"   "no"
  set_sshd_opt "PasswordAuthentication" "yes"
  set_sshd_opt "X11Forwarding"          "no"
  set_sshd_opt "MaxAuthTries"           "5"

  # Remove drop-in overrides that might disable password auth (Ubuntu 22.04+)
  local dropin_dir="/etc/ssh/sshd_config.d"
  if [[ -d "$dropin_dir" ]]; then
    for f in "$dropin_dir"/*.conf; do
      [[ -f "$f" ]] || continue
      if grep -qiE '^\s*PasswordAuthentication\s+no' "$f" 2>/dev/null; then
        info "Fixing $f — changing PasswordAuthentication to yes"
        sed -i 's|^\s*PasswordAuthentication\s\+no|PasswordAuthentication yes|i' "$f"
      fi
    done
  fi

  # Reload sshd to pick up changes
  if systemctl list-unit-files ssh.service &>/dev/null 2>&1; then
    systemctl reload ssh  2>/dev/null || systemctl restart ssh
  else
    systemctl reload sshd 2>/dev/null || systemctl restart sshd
  fi
  info "sshd config reloaded."
}

# ---------- verify password auth actually works --------------------------------
verify_password_auth() {
  # Check the effective sshd config to confirm password auth is on
  if command -v sshd &>/dev/null; then
    local effective
    effective=$(sshd -T 2>/dev/null | grep -i "^passwordauthentication" || true)
    if echo "$effective" | grep -qi "no"; then
      warn "sshd reports PasswordAuthentication is still OFF."
      warn "There may be an override file. Check /etc/ssh/sshd_config.d/"
      warn "You may not be able to log in with a password until this is fixed."
    elif echo "$effective" | grep -qi "yes"; then
      info "Verified: PasswordAuthentication is ON."
    fi
  fi

  # Confirm the vaultadmin user exists
  if id vaultadmin &>/dev/null; then
    info "Verified: vaultadmin user exists on this system."
  else
    warn "User 'vaultadmin' does NOT exist on this system!"
    warn "Create it with:  sudo adduser vaultadmin"
  fi
}

# ---------- print summary ----------------------------------------------------
print_summary() {
  local ip
  # Try to get the main non-loopback IP
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  [[ -z "$ip" ]] && ip=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
  [[ -z "$ip" ]] && ip="<could not detect>"

  info "============================================================"
  info "SSH SERVER IS READY"
  info "============================================================"
  echo ""
  echo "  Local IP address : $ip"
  echo "  SSH port         : 22"
  echo "  Username         : vaultadmin"
  echo "  Password         : vaultadmin"
  echo ""
  echo "  Test locally     : ssh vaultadmin@localhost"
  echo "  Test from LAN    : ssh vaultadmin@${ip}"
  echo ""
  echo "  To check status  : sudo systemctl status ssh  (or sshd)"
  echo "  To view logs     : sudo journalctl -eu ssh    (or sshd)"
  echo ""
  info "============================================================"
  info "NEXT: To access from outside the home network, see"
  info "SSH-SETUP-GUIDE.md in this repo or install Tailscale:"
  info "  curl -fsSL https://tailscale.com/install.sh | sh"
  info "============================================================"
}

# ---------- main -------------------------------------------------------------
main() {
  need_root
  detect_distro
  install_ssh
  start_sshd
  open_firewall
  harden_sshd
  verify_password_auth
  print_summary
}

main "$@"
