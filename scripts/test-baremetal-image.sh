#!/bin/bash
# Test bare metal image before deployment to physical hardware
# This script boots the image in QEMU for validation

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=============================================="
echo "Vault Cube Bare Metal Image Tester"
echo "Testing image before physical deployment"
echo -e "===============================================${NC}"
echo ""

# Configuration
IMAGE_PATH="${1:-packer/ubuntu-24.04/output-baremetal/vault-cube-baremetal}"
IMAGE_FORMAT="${2:-raw}"
MEMORY="${3:-8192}"  # 8GB for testing (vs 256GB on real hardware)
CPUS="${4:-4}"       # 4 CPUs for testing (vs 32 on real hardware)

FULL_IMAGE_PATH="${IMAGE_PATH}"
if [[ ! "$FULL_IMAGE_PATH" == *.* ]]; then
    FULL_IMAGE_PATH="${IMAGE_PATH}.${IMAGE_FORMAT}"
fi

echo -e "${YELLOW}Test Configuration:${NC}"
echo "  Image:  $FULL_IMAGE_PATH"
echo "  Format: $IMAGE_FORMAT"
echo "  Memory: ${MEMORY}MB"
echo "  CPUs:   $CPUS"
echo ""

# Check if image exists
if [ ! -f "$FULL_IMAGE_PATH" ]; then
    echo -e "${RED}ERROR: Image not found at: $FULL_IMAGE_PATH${NC}"
    echo ""
    echo "Build the image first:"
    echo "  ./scripts/build-baremetal.sh $IMAGE_FORMAT"
    exit 1
fi

# Check for QEMU
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo -e "${RED}ERROR: QEMU not found${NC}"
    echo "Install QEMU:"
    echo "  macOS:  brew install qemu"
    echo "  Ubuntu: sudo apt-get install qemu-system-x86"
    exit 1
fi

# Detect accelerator
ACCEL_ARGS=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    ACCEL_ARGS="-accel hvf"
    echo -e "${GREEN}Using macOS HVF acceleration${NC}"
elif [ -e /dev/kvm ] && [ -w /dev/kvm ]; then
    ACCEL_ARGS="-accel kvm"
    echo -e "${GREEN}Using Linux KVM acceleration${NC}"
else
    echo -e "${YELLOW}Using TCG software emulation (slow)${NC}"
fi

# Create temporary overlay (don't modify original image)
OVERLAY_IMAGE="/tmp/vault-cube-test-overlay.qcow2"
echo ""
echo -e "${YELLOW}Creating temporary overlay...${NC}"
qemu-img create -f qcow2 -b "$FULL_IMAGE_PATH" -F "$IMAGE_FORMAT" "$OVERLAY_IMAGE"

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"
    rm -f "$OVERLAY_IMAGE"
    echo -e "${GREEN}Cleanup complete${NC}"
}
trap cleanup EXIT

echo ""
echo -e "${GREEN}=============================================="
echo "Booting Image in QEMU"
echo -e "===============================================${NC}"
echo ""
echo "Login credentials:"
echo "  Username: vaultadmin"
echo "  Password: vaultadmin"
echo ""
echo "To test the system:"
echo "  1. Check kernel version:  uname -r"
echo "  2. Check Python:          python3 --version"
echo "  3. Check Docker:          docker --version"
echo "  4. Check CUDA:            nvcc --version"
echo "  5. Check PyTorch:         python3 -c 'import torch; print(torch.__version__)'"
echo ""
echo "Note: GPUs won't show in QEMU (no hardware), but software should be installed"
echo ""
echo -e "${YELLOW}Press Ctrl+A then X to exit QEMU${NC}"
echo ""
read -p "Press Enter to boot the image..."

# Boot the image
qemu-system-x86_64 \
    $ACCEL_ARGS \
    -m $MEMORY \
    -smp $CPUS \
    -drive file="$OVERLAY_IMAGE",format=qcow2,if=virtio \
    -net nic,model=virtio \
    -net user,hostfwd=tcp::2222-:22 \
    -vga std \
    -display default \
    -serial mon:stdio

echo ""
echo -e "${GREEN}Test complete!${NC}"
