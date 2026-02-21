#!/usr/bin/env bash
###############################################################################
# test-ssh-connectivity.sh — Diagnose SSH connectivity to a remote host
#
# Run this from YOUR machine (the one trying to connect) to diagnose
# whether you can reach the cube.
#
# Usage:
#   ./test-ssh-connectivity.sh <ip-or-hostname> [port]
#
# Examples:
#   ./test-ssh-connectivity.sh 192.168.1.50
#   ./test-ssh-connectivity.sh 100.100.100.1 22
#   ./test-ssh-connectivity.sh mycube.tail1234.ts.net
###############################################################################
set -euo pipefail

HOST="${1:-}"
PORT="${2:-22}"

if [[ -z "$HOST" ]]; then
  echo "Usage: $0 <ip-or-hostname> [port]"
  echo "  Example: $0 192.168.1.50"
  exit 1
fi

pass() { printf '  \033[1;32m✓ PASS\033[0m  %s\n' "$*"; }
fail() { printf '  \033[1;31m✗ FAIL\033[0m  %s\n' "$*"; }
skip() { printf '  \033[1;33m— SKIP\033[0m  %s\n' "$*"; }

echo ""
echo "======================================"
echo " SSH Connectivity Diagnostics"
echo " Target: $HOST:$PORT"
echo "======================================"
echo ""

# ---------- Test 1: DNS resolution ------------------------------------------
echo "[1/5] DNS resolution..."
if [[ "$HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  skip "Target is an IP address — DNS not needed."
else
  if host "$HOST" &>/dev/null 2>&1 || nslookup "$HOST" &>/dev/null 2>&1 || dig +short "$HOST" 2>/dev/null | grep -q .; then
    pass "DNS resolves: $HOST"
  else
    fail "Cannot resolve hostname: $HOST"
    echo "       Check spelling or try the IP address directly."
  fi
fi

# ---------- Test 2: ICMP ping -----------------------------------------------
echo ""
echo "[2/5] Ping (ICMP)..."
if ping -c 3 -W 3 "$HOST" &>/dev/null; then
  pass "Host responds to ping."
else
  fail "No ping response (host may block ICMP — this is not fatal)."
fi

# ---------- Test 3: TCP port reachability -----------------------------------
echo ""
echo "[3/5] TCP port $PORT reachability..."
if command -v nc &>/dev/null; then
  if nc -z -w 5 "$HOST" "$PORT" &>/dev/null; then
    pass "TCP port $PORT is open."
  else
    fail "TCP port $PORT is not reachable."
    echo "       Possible causes:"
    echo "         - SSH server not running on the cube"
    echo "         - Firewall blocking port $PORT"
    echo "         - Port forwarding not set up on the router"
    echo "         - Wrong IP address"
  fi
elif command -v bash &>/dev/null; then
  if (echo >/dev/tcp/"$HOST"/"$PORT") &>/dev/null; then
    pass "TCP port $PORT is open."
  else
    fail "TCP port $PORT is not reachable."
  fi
else
  skip "No nc or bash /dev/tcp available — cannot test port."
fi

# ---------- Test 4: SSH banner ----------------------------------------------
echo ""
echo "[4/5] SSH banner check..."
if command -v nc &>/dev/null; then
  banner=$(echo "" | nc -w 5 "$HOST" "$PORT" 2>/dev/null | head -1) || true
  if [[ "$banner" == *SSH* ]]; then
    pass "SSH banner received: $banner"
  elif [[ -n "$banner" ]]; then
    fail "Port $PORT responded but not with SSH banner: $banner"
  else
    fail "No SSH banner received."
  fi
elif command -v ssh &>/dev/null; then
  # Fallback: just try ssh with a short timeout
  if timeout 5 ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p "$PORT" "nobody@$HOST" 2>&1 | grep -qi "permission denied\|authentication"; then
    pass "SSH service is responding (got auth challenge)."
  else
    fail "Could not get SSH banner."
  fi
else
  skip "Neither nc nor ssh available."
fi

# ---------- Test 5: Full SSH connection test --------------------------------
echo ""
echo "[5/5] SSH authentication test..."
if command -v ssh &>/dev/null; then
  output=$(timeout 10 ssh -v -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p "$PORT" "test@$HOST" 2>&1) || true

  if echo "$output" | grep -qi "permission denied\|authentication"; then
    pass "SSH handshake works (auth denied as expected with dummy user)."
    echo "       You can connect! Run:"
    echo "       ssh vaultadmin@$HOST -p $PORT"
  elif echo "$output" | grep -qi "connection refused"; then
    fail "Connection refused — SSH may not be running on port $PORT."
  elif echo "$output" | grep -qi "timed out\|timeout"; then
    fail "Connection timed out — host unreachable or port blocked."
  elif echo "$output" | grep -qi "no route"; then
    fail "No route to host — network path issue."
  else
    fail "Unexpected SSH result. Verbose output:"
    echo "$output" | tail -5
  fi
else
  skip "ssh client not installed."
fi

echo ""
echo "======================================"
echo " Diagnostics complete."
echo "======================================"
echo ""
