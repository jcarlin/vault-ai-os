#!/bin/bash
# Test autoinstall ISO in QEMU
# Boots the ISO, waits for install to complete, verifies SSH access

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
ISO_PATH="${1:-$PROJECT_ROOT/output/vault-cube-24.04-autoinstall.iso}"
TEST_DISK="/tmp/vault-cube-test.qcow2"
DISK_SIZE="50G"
MEMORY="4096"
CPUS="2"
SSH_PORT="2222"
SSH_USER="vaultadmin"
SSH_PASS="vaultadmin"

# Timeouts (in seconds)
INSTALL_TIMEOUT=3600   # 60 minutes max for install
SSH_CHECK_INTERVAL=30  # Check SSH every 30 seconds
SSH_TIMEOUT=60         # SSH connection timeout

# Mode
MODE="${2:-interactive}"  # interactive, headless, or quick

echo -e "${BLUE}=============================================="
echo "Vault Cube Autoinstall ISO Tester"
echo "QEMU-based automated installation test"
echo -e "===============================================${NC}"
echo ""

# Print usage
usage() {
    echo "Usage: $0 [iso-path] [mode]"
    echo ""
    echo "Arguments:"
    echo "  iso-path   Path to autoinstall ISO (default: output/vault-cube-24.04-autoinstall.iso)"
    echo "  mode       Test mode: interactive, headless, or quick (default: interactive)"
    echo ""
    echo "Modes:"
    echo "  interactive  - Show QEMU window, wait for user to close"
    echo "  headless     - Run in background, wait for SSH, verify, cleanup"
    echo "  quick        - Just boot and verify ISO loads (no full install)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Interactive with default ISO"
    echo "  $0 output/vault-cube-24.04-autoinstall.iso headless"
    echo "  $0 /path/to/custom.iso quick"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    local missing=0

    if ! command -v qemu-system-x86_64 &> /dev/null; then
        echo -e "${RED}ERROR: qemu-system-x86_64 not found${NC}"
        echo "Install QEMU:"
        echo "  macOS:  brew install qemu"
        echo "  Ubuntu: sudo apt-get install qemu-system-x86"
        missing=1
    else
        echo -e "${GREEN}  qemu-system-x86_64: found${NC}"
    fi

    if ! command -v qemu-img &> /dev/null; then
        echo -e "${RED}ERROR: qemu-img not found${NC}"
        missing=1
    else
        echo -e "${GREEN}  qemu-img: found${NC}"
    fi

    if [ "$MODE" = "headless" ]; then
        if ! command -v sshpass &> /dev/null; then
            echo -e "${YELLOW}  sshpass: not found (optional, will use expect or manual)${NC}"
        else
            echo -e "${GREEN}  sshpass: found${NC}"
        fi
    fi

    if [ $missing -eq 1 ]; then
        exit 1
    fi
    echo ""
}

# Validate ISO
validate_iso() {
    if [ ! -f "$ISO_PATH" ]; then
        echo -e "${RED}ERROR: ISO not found at: $ISO_PATH${NC}"
        echo ""
        echo "Build the ISO first:"
        echo "  ./scripts/create-autoinstall-iso.sh ~/Downloads/ubuntu-24.04.3-live-server-amd64.iso"
        exit 1
    fi
    echo -e "${GREEN}ISO found: $ISO_PATH${NC}"
    echo "  Size: $(ls -lh "$ISO_PATH" | awk '{print $5}')"
    echo ""
}

# Detect accelerator
detect_accelerator() {
    ACCEL_ARGS=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ACCEL_ARGS="-accel hvf"
        echo -e "${GREEN}Using macOS HVF acceleration${NC}"
    elif [ -e /dev/kvm ] && [ -w /dev/kvm ]; then
        ACCEL_ARGS="-accel kvm"
        echo -e "${GREEN}Using Linux KVM acceleration${NC}"
    else
        echo -e "${YELLOW}Using TCG software emulation (slow)${NC}"
        ACCEL_ARGS="-accel tcg"
    fi
}

# Create test disk
create_test_disk() {
    echo -e "${YELLOW}Creating test disk: $TEST_DISK ($DISK_SIZE)${NC}"
    rm -f "$TEST_DISK"
    qemu-img create -f qcow2 "$TEST_DISK" "$DISK_SIZE" > /dev/null
    echo -e "${GREEN}  Test disk created${NC}"
    echo ""
}

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"

    # Kill QEMU if running
    if [ -n "${QEMU_PID:-}" ]; then
        if kill -0 "$QEMU_PID" 2>/dev/null; then
            echo "  Stopping QEMU (PID: $QEMU_PID)"
            kill "$QEMU_PID" 2>/dev/null || true
            sleep 2
            kill -9 "$QEMU_PID" 2>/dev/null || true
        fi
    fi

    # Also kill by port
    local pids=$(lsof -ti:$SSH_PORT 2>/dev/null || true)
    if [ -n "$pids" ]; then
        echo "  Killing processes on port $SSH_PORT"
        echo "$pids" | xargs kill 2>/dev/null || true
    fi

    # Remove test disk
    if [ -f "$TEST_DISK" ]; then
        echo "  Removing test disk"
        rm -f "$TEST_DISK"
    fi

    echo -e "${GREEN}Cleanup complete${NC}"
}

# Wait for SSH
wait_for_ssh() {
    local max_attempts=$((INSTALL_TIMEOUT / SSH_CHECK_INTERVAL))
    local attempt=0

    echo -e "${YELLOW}Waiting for installation to complete and SSH to become available...${NC}"
    echo "  This typically takes 15-30 minutes"
    echo "  Checking every ${SSH_CHECK_INTERVAL}s (timeout: ${INSTALL_TIMEOUT}s)"
    echo ""

    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        local elapsed=$((attempt * SSH_CHECK_INTERVAL))

        # Check if QEMU is still running
        if ! kill -0 "$QEMU_PID" 2>/dev/null; then
            echo -e "${RED}QEMU process died unexpectedly${NC}"
            return 1
        fi

        # Check if port is open
        if nc -z localhost $SSH_PORT 2>/dev/null; then
            # Try SSH connection
            if sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ServerAliveInterval=5 -p $SSH_PORT ${SSH_USER}@localhost "echo 'SSH OK'" 2>/dev/null; then
                echo ""
                echo -e "${GREEN}SSH connection successful after ${elapsed}s${NC}"
                return 0
            fi
        fi

        # Progress indicator
        printf "\r  [%3d/%3ds] Waiting for install... " "$elapsed" "$INSTALL_TIMEOUT"
        sleep $SSH_CHECK_INTERVAL
    done

    echo ""
    echo -e "${RED}Timeout waiting for SSH after ${INSTALL_TIMEOUT}s${NC}"
    return 1
}

# Run verification commands
run_verification() {
    echo ""
    echo -e "${BLUE}Running verification checks...${NC}"
    echo ""

    local ssh_cmd="sshpass -p $SSH_PASS ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $SSH_PORT ${SSH_USER}@localhost"
    local failed=0

    # Check user
    echo -n "  User 'vaultadmin' exists: "
    if $ssh_cmd "id vaultadmin" &>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        failed=1
    fi

    # Check sudo
    echo -n "  Passwordless sudo works: "
    if $ssh_cmd "sudo -n whoami" 2>/dev/null | grep -q root; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        failed=1
    fi

    # Check SSH service
    echo -n "  SSH service running: "
    if $ssh_cmd "systemctl is-active ssh" 2>/dev/null | grep -q active; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        failed=1
    fi

    # Check hostname
    echo -n "  Hostname set: "
    local hostname=$($ssh_cmd "hostname" 2>/dev/null)
    if [ -n "$hostname" ]; then
        echo -e "${GREEN}PASS${NC} ($hostname)"
    else
        echo -e "${RED}FAIL${NC}"
        failed=1
    fi

    # Check network
    echo -n "  Network configured: "
    if $ssh_cmd "ip addr show | grep -q 'inet '" &>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        failed=1
    fi

    # Check disk space
    echo -n "  Disk mounted: "
    local disk_info=$($ssh_cmd "df -h / | tail -1 | awk '{print \$2}'" 2>/dev/null)
    if [ -n "$disk_info" ]; then
        echo -e "${GREEN}PASS${NC} (root: $disk_info)"
    else
        echo -e "${RED}FAIL${NC}"
        failed=1
    fi

    # System info
    echo ""
    echo -e "${BLUE}System Information:${NC}"
    echo "  OS: $($ssh_cmd "cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"'" 2>/dev/null)"
    echo "  Kernel: $($ssh_cmd "uname -r" 2>/dev/null)"
    echo "  Uptime: $($ssh_cmd "uptime -p" 2>/dev/null)"

    return $failed
}

# Interactive mode
run_interactive() {
    echo -e "${BLUE}Starting QEMU in interactive mode...${NC}"
    echo ""
    echo "The QEMU window will open. You can:"
    echo "  1. Watch the autoinstall progress"
    echo "  2. After install completes, the system will reboot"
    echo "  3. Login as vaultadmin/vaultadmin"
    echo ""
    echo "SSH will be available at: localhost:$SSH_PORT"
    echo "  ssh -p $SSH_PORT vaultadmin@localhost"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop, or close QEMU window when done${NC}"
    echo ""

    trap cleanup EXIT

    qemu-system-x86_64 \
        $ACCEL_ARGS \
        -m $MEMORY \
        -smp $CPUS \
        -cdrom "$ISO_PATH" \
        -drive file="$TEST_DISK",format=qcow2,if=virtio \
        -boot d \
        -net nic,model=virtio \
        -net user,hostfwd=tcp::${SSH_PORT}-:22 \
        -vga std \
        -display default
}

# Headless mode
run_headless() {
    echo -e "${BLUE}Starting QEMU in headless mode...${NC}"
    echo ""

    trap cleanup EXIT

    # Start QEMU in background
    qemu-system-x86_64 \
        $ACCEL_ARGS \
        -m $MEMORY \
        -smp $CPUS \
        -cdrom "$ISO_PATH" \
        -drive file="$TEST_DISK",format=qcow2,if=virtio \
        -boot d \
        -net nic,model=virtio \
        -net user,hostfwd=tcp::${SSH_PORT}-:22 \
        -nographic \
        -serial mon:stdio &

    QEMU_PID=$!
    echo "QEMU started with PID: $QEMU_PID"
    echo "SSH will be forwarded to port: $SSH_PORT"
    echo ""

    # Wait for SSH
    if wait_for_ssh; then
        # Run verification
        if run_verification; then
            echo ""
            echo -e "${GREEN}=============================================="
            echo "ALL TESTS PASSED!"
            echo -e "===============================================${NC}"
            exit 0
        else
            echo ""
            echo -e "${RED}=============================================="
            echo "SOME TESTS FAILED"
            echo -e "===============================================${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Installation failed or timed out${NC}"
        exit 1
    fi
}

# Timeout wrapper for macOS/Linux compatibility
run_with_timeout() {
    local timeout_sec=$1
    shift
    if command -v gtimeout &>/dev/null; then
        gtimeout "$timeout_sec" "$@"
    elif command -v timeout &>/dev/null; then
        timeout "$timeout_sec" "$@"
    else
        # Fallback: run in background and kill after timeout
        "$@" &
        local pid=$!
        ( sleep "$timeout_sec"; kill "$pid" 2>/dev/null ) &
        local killer=$!
        wait "$pid" 2>/dev/null
        kill "$killer" 2>/dev/null || true
    fi
}

# Quick mode - just verify ISO boots
run_quick() {
    echo -e "${BLUE}Starting QEMU in quick mode (boot test only)...${NC}"
    echo ""
    echo "This will verify the ISO boots and reaches the installer."
    echo "Press Ctrl+C after seeing GRUB/installer to confirm success."
    echo ""

    trap cleanup EXIT

    # Boot with serial console to see output
    run_with_timeout 120 qemu-system-x86_64 \
        $ACCEL_ARGS \
        -m $MEMORY \
        -smp $CPUS \
        -cdrom "$ISO_PATH" \
        -drive file="$TEST_DISK",format=qcow2,if=virtio \
        -boot d \
        -net nic,model=virtio \
        -net user \
        -nographic \
        -serial mon:stdio || true

    echo ""
    echo -e "${GREEN}Quick boot test complete${NC}"
    echo "If you saw GRUB menu and installer starting, the ISO is working."
}

# Main
main() {
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        usage
    fi

    check_prerequisites
    validate_iso
    detect_accelerator
    create_test_disk

    echo -e "${BLUE}Test Configuration:${NC}"
    echo "  ISO:     $ISO_PATH"
    echo "  Mode:    $MODE"
    echo "  Memory:  ${MEMORY}MB"
    echo "  CPUs:    $CPUS"
    echo "  Disk:    $TEST_DISK ($DISK_SIZE)"
    echo "  SSH:     localhost:$SSH_PORT"
    echo ""

    case "$MODE" in
        interactive)
            run_interactive
            ;;
        headless)
            run_headless
            ;;
        quick)
            run_quick
            ;;
        *)
            echo -e "${RED}Unknown mode: $MODE${NC}"
            usage
            ;;
    esac
}

main "$@"
