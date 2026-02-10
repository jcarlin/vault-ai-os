#!/bin/bash
set -e

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT=$(gcloud config get-value project 2>/dev/null)
REGION=$(gcloud config get-value compute/region 2>/dev/null)

if [ -z "$PROJECT" ]; then
    echo -e "${RED}ERROR: No GCP project configured${NC}"
    echo "Run: ./scripts/setup-gcp.sh"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   GCP GPU Quota & Availability Check                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Project: $PROJECT"
echo "Region: $REGION"
echo ""

# Check L4 GPU quota
echo -e "${YELLOW}1. L4 GPU Quotas in $REGION:${NC}"
echo ""

L4_QUOTA=$(gcloud compute regions describe $REGION \
    --format="value(quotas.filter(metric:nvidia_l4).limit)" 2>/dev/null || echo "0")
L4_USAGE=$(gcloud compute regions describe $REGION \
    --format="value(quotas.filter(metric:nvidia_l4).usage)" 2>/dev/null || echo "0")

if [ "$L4_QUOTA" = "0" ] || [ -z "$L4_QUOTA" ]; then
    echo -e "${RED}  ✗ No L4 GPU quota available${NC}"
    echo ""
    echo "  To request quota increase:"
    echo "  1. Visit: https://console.cloud.google.com/iam-admin/quotas?project=$PROJECT"
    echo "  2. Filter: 'nvidia_l4' + '$REGION'"
    echo "  3. Select 'NVIDIA L4 GPUs' → Edit Quotas"
    echo "  4. New limit: 4-8 GPUs"
    echo "  5. Justification: 'GPU-accelerated ML training and validation for Vault Cube project'"
else
    AVAILABLE=$((L4_QUOTA - L4_USAGE))
    if [ "$AVAILABLE" -ge "4" ]; then
        echo -e "${GREEN}  ✓ Quota: $L4_QUOTA GPUs (Using: $L4_USAGE, Available: $AVAILABLE)${NC}"
    elif [ "$AVAILABLE" -ge "1" ]; then
        echo -e "${YELLOW}  ⚠ Quota: $L4_QUOTA GPUs (Using: $L4_USAGE, Available: $AVAILABLE)${NC}"
        echo "    Sufficient for single-GPU testing, consider increase for multi-GPU"
    else
        echo -e "${RED}  ✗ Quota exhausted: $L4_QUOTA GPUs (Using: $L4_USAGE, Available: 0)${NC}"
    fi
fi
echo ""

# Show all GPU-related quotas
echo -e "${YELLOW}2. All GPU Quotas in $REGION:${NC}"
echo ""
gcloud compute regions describe $REGION \
    --format="table(
        quotas.filter(metric~'nvidia|gpu').metric,
        quotas.filter(metric~'nvidia|gpu').limit,
        quotas.filter(metric~'nvidia|gpu').usage
    )" 2>/dev/null || echo "  No GPU quotas found"
echo ""

# Check available zones for L4
echo -e "${YELLOW}3. L4 GPU Availability by Zone:${NC}"
echo ""
gcloud compute accelerator-types list \
    --filter="name:nvidia-l4 AND zone~$REGION" \
    --format="table(name,zone,description)" 2>/dev/null || echo "  No L4 GPUs available"
echo ""

# Check other GPU types
echo -e "${YELLOW}4. Other GPU Types in $REGION:${NC}"
echo ""
gcloud compute accelerator-types list \
    --filter="zone~$REGION" \
    --format="table(name,zone)" | head -20
echo ""

# Check current GPU instance usage
echo -e "${YELLOW}5. Current GPU Instances:${NC}"
echo ""
INSTANCES=$(gcloud compute instances list \
    --filter="zone~$REGION AND guestAccelerators:*" \
    --format="table(
        name,
        zone,
        machineType.basename(),
        guestAccelerators[].acceleratorType.basename(),
        guestAccelerators[].acceleratorCount,
        status
    )" 2>/dev/null)

if [ -z "$INSTANCES" ] || [ "$INSTANCES" = "Listed 0 items." ]; then
    echo -e "${GREEN}  No GPU instances currently running${NC}"
else
    echo "$INSTANCES"
fi
echo ""

# Check compute engine quotas
echo -e "${YELLOW}6. Compute Engine Quotas:${NC}"
echo ""
gcloud compute regions describe $REGION \
    --format="table(
        quotas.filter(metric~'CPUS|DISKS_TOTAL_GB|IN_USE_ADDRESSES').metric,
        quotas.filter(metric~'CPUS|DISKS_TOTAL_GB|IN_USE_ADDRESSES').limit,
        quotas.filter(metric~'CPUS|DISKS_TOTAL_GB|IN_USE_ADDRESSES').usage
    )" 2>/dev/null
echo ""

# Recommendations
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Recommendations                                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$L4_QUOTA" = "0" ] || [ -z "$L4_QUOTA" ]; then
    echo -e "${YELLOW}⚠ Action Required: Request L4 GPU quota${NC}"
    echo ""
    echo "Recommended quota: 4-8 GPUs"
    echo "Processing time: 1-2 business days"
    echo ""
elif [ "$AVAILABLE" -ge "4" ]; then
    echo -e "${GREEN}✓ Ready to build GPU images!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Navigate to packer directory: ${GREEN}cd packer${NC}"
    echo "  2. Initialize Packer: ${GREEN}packer init .${NC}"
    echo "  3. Validate configuration: ${GREEN}packer validate -only=cloud-gpu-gcp .${NC}"
    echo "  4. Build GPU image: ${GREEN}packer build -only=cloud-gpu-gcp .${NC}"
    echo ""
elif [ "$AVAILABLE" -ge "1" ]; then
    echo -e "${YELLOW}✓ Ready for single-GPU testing${NC}"
    echo ""
    echo "Current quota sufficient for:"
    echo "  • Packer image builds (1 GPU required)"
    echo "  • Single-GPU validation testing"
    echo ""
    echo "For multi-GPU (4x RTX 5090 simulation):"
    echo "  • Request quota increase to 4-8 GPUs"
    echo ""
else
    echo -e "${RED}⚠ GPU quota exhausted${NC}"
    echo ""
    echo "Current usage: $L4_USAGE / $L4_QUOTA GPUs"
    echo ""
    echo "Options:"
    echo "  1. Delete unused GPU instances"
    echo "  2. Request quota increase"
    echo "  3. Use different region"
    echo ""
fi

# Cost estimate
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Estimated Costs (with Preemptible Instances)        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Build (1hr, g2-standard-4 + L4): ~\$0.35"
echo "  Testing (6hrs, g2-standard-8 + L4): ~\$2.88"
echo "  Total: ~\$3.25"
echo ""
echo -e "${GREEN}FREE if using \$300 new account credit!${NC}"
echo ""
