#!/bin/bash
# Quick validation build - builds with minimal resources for fast testing
# Use this to verify configuration before full build

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=============================================="
echo "Quick Test Build"
echo "Minimal resources for fast validation"
echo -e "===============================================${NC}"
echo ""

# Navigate to packer directory
cd "$(dirname "$0")/../packer/ubuntu-24.04"

# Detect accelerator
ACCELERATOR="tcg"
if [[ "$OSTYPE" == "darwin"* ]]; then
    ACCELERATOR="hvf"
    echo -e "${GREEN}Detected macOS - using HVF${NC}"
elif grep -q "^flags.*\<vmx\>\|\<svm\>" /proc/cpuinfo 2>/dev/null; then
    if [ -e /dev/kvm ] && [ -w /dev/kvm ]; then
        ACCELERATOR="kvm"
        echo -e "${GREEN}Detected KVM${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}Building with reduced specs for quick testing:${NC}"
echo "  CPUs:   4 (vs 32 production)"
echo "  Memory: 8GB (vs 256GB production)"
echo "  Disk:   50GB (vs 2TB production)"
echo ""

# Check for Packer
if ! command -v packer &> /dev/null; then
    echo -e "${RED}ERROR: Packer not found${NC}"
    exit 1
fi

# Initialize
echo -e "${YELLOW}Initializing Packer...${NC}"
packer init .

# Validate
echo -e "${YELLOW}Validating configuration...${NC}"
packer validate \
    -var="baremetal_cpus=4" \
    -var="baremetal_memory=8192" \
    -var="baremetal_disk_size=50G" \
    -var="baremetal_output_format=qcow2" \
    -var="baremetal_accelerator=$ACCELERATOR" \
    -var="baremetal_headless=false" \
    .

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Validation passed!${NC}"
    echo ""
    echo "Ready to build. Run one of:"
    echo ""
    echo "  1. Quick test build (4 CPU, 8GB RAM, 50GB disk):"
    echo "     packer build -only='baremetal-gpu.qemu.ubuntu-2404-baremetal' \\"
    echo "       -var='baremetal_cpus=4' \\"
    echo "       -var='baremetal_memory=8192' \\"
    echo "       -var='baremetal_disk_size=50G' \\"
    echo "       -var='baremetal_output_format=qcow2' \\"
    echo "       -var='baremetal_accelerator=$ACCELERATOR' \\"
    echo "       -var='baremetal_headless=false' \\"
    echo "       ."
    echo ""
    echo "  2. Full production build:"
    echo "     ./scripts/build-baremetal.sh raw"
    echo ""
else
    echo -e "${RED}✗ Validation failed${NC}"
    exit 1
fi
