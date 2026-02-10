#!/bin/bash
# Build bare metal bootable image for Vault Cube physical hardware
# Optimized for 4x RTX 5090, 256GB RAM, 2TB NVMe SSD

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=============================================="
echo "Vault Cube Bare Metal Image Builder"
echo "Ubuntu 24.04 + RTX 5090 Full Stack"
echo -e "===============================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check for QEMU
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo -e "${RED}ERROR: QEMU not found${NC}"
    echo "Install QEMU:"
    echo "  macOS:  brew install qemu"
    echo "  Ubuntu: sudo apt-get install qemu-system-x86 qemu-utils"
    echo "  Fedora: sudo dnf install qemu-system-x86"
    exit 1
fi

# Check for Packer
if ! command -v packer &> /dev/null; then
    echo -e "${RED}ERROR: Packer not found${NC}"
    echo "Install Packer:"
    echo "  macOS:  brew install packer"
    echo "  Ubuntu: https://www.packer.io/downloads"
    exit 1
fi

# Check for ISO file
ISO_PATH="/Users/julian/Downloads/ubuntu-24.04.3-live-server-amd64.iso"
if [ ! -f "$ISO_PATH" ]; then
    echo -e "${YELLOW}WARNING: Ubuntu 24.04.3 ISO not found at: $ISO_PATH${NC}"
    echo "Download from: https://releases.ubuntu.com/24.04/"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Detect accelerator
ACCELERATOR="tcg"  # Default fallback
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - use hvf (Hypervisor.framework)
    ACCELERATOR="hvf"
    echo -e "${GREEN}Detected macOS - using HVF accelerator${NC}"
elif grep -q "^flags.*\<vmx\>\|\<svm\>" /proc/cpuinfo 2>/dev/null; then
    # Linux with KVM support
    if [ -e /dev/kvm ] && [ -w /dev/kvm ]; then
        ACCELERATOR="kvm"
        echo -e "${GREEN}Detected KVM support - using KVM accelerator${NC}"
    else
        echo -e "${YELLOW}KVM device not accessible - using TCG (slow)${NC}"
        echo "Run: sudo usermod -aG kvm $USER && newgrp kvm"
    fi
else
    echo -e "${YELLOW}No virtualization support detected - using TCG (slow)${NC}"
fi

# Configuration
OUTPUT_FORMAT="${1:-raw}"  # raw, qcow2, or iso
HEADLESS="${2:-true}"      # true or false

echo ""
echo -e "${BLUE}Build Configuration:${NC}"
echo "  Output Format: $OUTPUT_FORMAT"
echo "  Accelerator:   $ACCELERATOR"
echo "  Headless:      $HEADLESS"
echo "  Target:        Vault Cube (4x RTX 5090, 256GB RAM, 2TB NVMe)"
echo ""

# Navigate to packer directory
cd "$(dirname "$0")/../packer/ubuntu-24.04"

# Initialize Packer plugins
echo -e "${YELLOW}Initializing Packer plugins...${NC}"
packer init .

# Validate configuration
echo -e "${YELLOW}Validating Packer configuration...${NC}"
packer validate \
    -var="baremetal_output_format=$OUTPUT_FORMAT" \
    -var="baremetal_accelerator=$ACCELERATOR" \
    -var="baremetal_headless=$HEADLESS" \
    .

# Build the image
echo ""
echo -e "${GREEN}Starting bare metal image build...${NC}"
echo -e "${YELLOW}This will take 30-60 minutes depending on your system${NC}"
echo ""

packer build \
    -only="baremetal-gpu.qemu.ubuntu-2404-baremetal" \
    -var="baremetal_output_format=$OUTPUT_FORMAT" \
    -var="baremetal_accelerator=$ACCELERATOR" \
    -var="baremetal_headless=$HEADLESS" \
    .

# Check for output
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=============================================="
    echo "Build Complete!"
    echo -e "===============================================${NC}"
    echo ""
    echo "Output image: output-baremetal/vault-cube-baremetal.$OUTPUT_FORMAT"
    echo ""
    echo -e "${BLUE}Deployment Instructions:${NC}"
    echo ""
    echo "1. Write to USB drive (for installation):"
    echo "   sudo dd if=output-baremetal/vault-cube-baremetal.$OUTPUT_FORMAT of=/dev/sdX bs=4M status=progress"
    echo ""
    echo "2. Write to Vault Cube NVMe SSD (direct deployment):"
    echo "   Boot from USB live system, then:"
    echo "   sudo dd if=/path/to/vault-cube-baremetal.$OUTPUT_FORMAT of=/dev/nvme0n1 bs=4M status=progress"
    echo ""
    echo "3. Verify written image:"
    echo "   sudo fdisk -l /dev/sdX"
    echo ""
    echo -e "${YELLOW}IMPORTANT: Double-check device names to avoid data loss!${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}Build failed! Check output above for errors.${NC}"
    exit 1
fi
