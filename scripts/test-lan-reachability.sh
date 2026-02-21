#!/usr/bin/env bash
###############################################################################
# test-lan-reachability.sh — Run FROM YOUR LAPTOP to check if the cube is
# reachable on the local network BEFORE installing SSH.
#
# This is Step 0: Can your laptop even talk to the cube on the LAN?
#
# Usage:
#   chmod +x test-lan-reachability.sh
#   ./test-lan-reachability.sh 192.168.1.50
#
# Replace 192.168.1.50 with the cube's actual static IP address.
###############################################################################
set -euo pipefail

HOST="${1:-}"

if [[ -z "$HOST" ]]; then
  echo ""
  echo "Usage: $0 <cube-ip-address>"
  echo ""
  echo "  Example: $0 192.168.1.50"
  echo ""
  echo "  Run this from YOUR LAPTOP (not the cube) to check if you"
  echo "  can reach the cube on the local network."
  echo ""
  exit 1
fi

pass() { printf '  \033[1;32m✓ PASS\033[0m  %s\n' "$*"; }
fail() { printf '  \033[1;31m✗ FAIL\033[0m  %s\n' "$*"; }
info() { printf '  \033[1;34mℹ INFO\033[0m  %s\n' "$*"; }

echo ""
echo "================================================"
echo "  LAN Reachability Test"
echo "  Target: $HOST"
echo "================================================"
echo ""

# ---------- Test 0: Are we on a network at all? -----------------------------
echo "[1/5] Checking your laptop's network connection..."
MY_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
if [[ -z "$MY_IP" ]]; then
  MY_IP=$(ipconfig getifaddr en0 2>/dev/null || true)  # macOS
fi

if [[ -n "$MY_IP" ]]; then
  pass "Your laptop IP: $MY_IP"
else
  fail "Cannot detect your laptop's IP address."
  echo "       Are you connected to wifi / ethernet?"
  exit 1
fi

# ---------- Test 1: Same subnet check --------------------------------------
echo ""
echo "[2/5] Checking if you and the cube are on the same subnet..."

# Extract first 3 octets (works for typical /24 home networks)
MY_SUBNET=$(echo "$MY_IP" | cut -d. -f1-3)
TARGET_SUBNET=$(echo "$HOST" | cut -d. -f1-3)

if [[ "$MY_SUBNET" == "$TARGET_SUBNET" ]]; then
  pass "Same subnet ($MY_SUBNET.x) — good, you're on the same network."
else
  fail "Different subnets: yours=$MY_SUBNET.x  cube=$TARGET_SUBNET.x"
  echo "       This usually means you're on different networks."
  echo "       Make sure your laptop is on the same wifi / switch as the cube."
  echo "       (Continuing tests anyway in case subnets are routed...)"
fi

# ---------- Test 2: Ping ---------------------------------------------------
echo ""
echo "[3/5] Pinging the cube ($HOST)..."

# Detect OS for ping syntax
if [[ "$(uname)" == "Darwin" ]]; then
  PING_CMD="ping -c 4 -W 2000 $HOST"   # macOS: -W is ms
else
  PING_CMD="ping -c 4 -W 2 $HOST"      # Linux: -W is seconds
fi

PING_OUTPUT=$($PING_CMD 2>&1) || true

if echo "$PING_OUTPUT" | grep -q "bytes from"; then
  PING_MS=$(echo "$PING_OUTPUT" | grep "avg" | sed 's|.*/\([0-9.]*\)/.*|\1|' 2>/dev/null || echo "?")
  pass "Cube responds to ping! (avg ${PING_MS}ms)"
  echo ""
  echo "$PING_OUTPUT" | grep -E "bytes from|packet loss|avg" | while read -r line; do
    echo "       $line"
  done
else
  fail "No ping response from $HOST"
  echo ""
  echo "       Possible causes:"
  echo "         1. Wrong IP address — double-check the cube's IP"
  echo "         2. Cube is powered off or not on the network"
  echo "         3. Cube's firewall is blocking ICMP (less common on LAN)"
  echo "         4. Your laptop is on a different network/VLAN"
  echo ""
  echo "       Things to try:"
  echo "         - On the cube, run: ip addr show | grep 'inet '"
  echo "         - Confirm both devices are on the same wifi network"
  echo "         - Try pinging your laptop FROM the cube: ping $MY_IP"
fi

# ---------- Test 3: ARP check (can we see the MAC address?) -----------------
echo ""
echo "[4/5] Checking ARP table for the cube..."

# Send a ping first to populate ARP (might have failed above but try again quietly)
ping -c 1 -W 1 "$HOST" &>/dev/null || true

ARP_ENTRY=""
if command -v arp &>/dev/null; then
  ARP_ENTRY=$(arp -n "$HOST" 2>/dev/null | grep -v "incomplete" | grep -v "no entry" | tail -1) || true
elif command -v ip &>/dev/null; then
  ARP_ENTRY=$(ip neigh show "$HOST" 2>/dev/null | grep -v "FAILED" | head -1) || true
fi

if [[ -n "$ARP_ENTRY" ]]; then
  pass "Cube found in ARP table — it's physically on your network."
  echo "       $ARP_ENTRY"
else
  fail "Cube not in ARP table — your laptop cannot see it at layer 2."
  echo "       This strongly suggests the cube is unreachable on the LAN."
  echo "       Check: cables, wifi, correct IP, power."
fi

# ---------- Test 4: Port 22 check ------------------------------------------
echo ""
echo "[5/5] Checking if SSH (port 22) is already open on the cube..."

PORT_OPEN=false
if command -v nc &>/dev/null; then
  if nc -z -w 3 "$HOST" 22 &>/dev/null; then
    PORT_OPEN=true
  fi
elif command -v bash &>/dev/null; then
  if (echo >/dev/tcp/"$HOST"/22) &>/dev/null; then
    PORT_OPEN=true
  fi
fi

if $PORT_OPEN; then
  pass "Port 22 is OPEN — SSH may already be running on the cube!"
  echo "       Try connecting: ssh <username>@$HOST"
else
  info "Port 22 is closed (expected if SSH isn't installed yet)."
  echo "       This is fine — once you run setup-ssh.sh on the cube,"
  echo "       this port should open up. Re-run this test afterward."
fi

# ---------- Summary ---------------------------------------------------------
echo ""
echo "================================================"
echo "  Summary"
echo "================================================"
echo ""

# Count passes/fails
if echo "$PING_OUTPUT" | grep -q "bytes from"; then
  echo "  Network reachability:  YES — the cube is alive on the LAN"
  echo ""
  echo "  NEXT STEPS:"
  echo "    1. On the cube, run the SSH setup script:"
  echo "       sudo ./setup-ssh.sh"
  echo "       (or paste the manual commands from SSH-SETUP-GUIDE.md)"
  echo ""
  echo "    2. Then re-run this script to confirm port 22 opens up"
  echo ""
  echo "    3. Test SSH: ssh <username>@$HOST"
else
  echo "  Network reachability:  NO — cannot reach the cube"
  echo ""
  echo "  BEFORE doing anything else, fix the network:"
  echo "    1. Is the cube powered on?"
  echo "    2. Is it plugged into the router (ethernet) or on wifi?"
  echo "    3. Confirm the IP on the cube: ip addr show"
  echo "    4. Are both devices on the same network?"
  echo "    5. Try pinging your laptop FROM the cube: ping $MY_IP"
fi
echo ""
