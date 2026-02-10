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
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   GCP Resource Cleanup & Cost Analysis                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Project: $PROJECT"
echo "Region: $REGION"
echo ""

# Function to confirm action
confirm() {
    read -p "$1 (y/n) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# 1. List and cleanup GPU instances
echo -e "${YELLOW}1. GPU Instances:${NC}"
echo ""

GPU_INSTANCES=$(gcloud compute instances list \
    --filter="zone~$REGION AND guestAccelerators:*" \
    --format="value(name,zone,status)" 2>/dev/null)

if [ -z "$GPU_INSTANCES" ]; then
    echo -e "${GREEN}  ✓ No GPU instances running${NC}"
else
    echo "Running GPU instances:"
    gcloud compute instances list \
        --filter="zone~$REGION AND guestAccelerators:*" \
        --format="table(name,zone,machineType.basename(),guestAccelerators[].acceleratorType.basename(),status,creationTimestamp)"
    echo ""

    if confirm "Delete all GPU instances?"; then
        echo "$GPU_INSTANCES" | while IFS=$'\t' read -r name zone status; do
            if [ -n "$name" ]; then
                echo "  Deleting $name in $zone..."
                gcloud compute instances delete $name --zone=$zone --quiet
            fi
        done
        echo -e "${GREEN}  ✓ GPU instances deleted${NC}"
    else
        echo "  Skipped"
    fi
fi
echo ""

# 2. List and cleanup custom images
echo -e "${YELLOW}2. Custom Images:${NC}"
echo ""

IMAGES=$(gcloud compute images list --filter="family~vault-cube" --format="value(name)" 2>/dev/null)

if [ -z "$IMAGES" ]; then
    echo -e "${GREEN}  ✓ No custom images found${NC}"
else
    IMAGE_COUNT=$(echo "$IMAGES" | wc -l | tr -d ' ')
    echo "Found $IMAGE_COUNT custom image(s):"
    gcloud compute images list --filter="family~vault-cube" \
        --format="table(name,family,creationTimestamp.date(),diskSizeGb)" \
        --sort-by=~creationTimestamp
    echo ""

    if [ "$IMAGE_COUNT" -gt "3" ]; then
        if confirm "Keep latest 3 images, delete older ones?"; then
            IMAGES_TO_DELETE=$(gcloud compute images list \
                --filter="family~vault-cube" \
                --format="value(name)" \
                --sort-by=~creationTimestamp | tail -n +4)

            echo "$IMAGES_TO_DELETE" | while read -r img; do
                if [ -n "$img" ]; then
                    echo "  Deleting $img..."
                    gcloud compute images delete $img --quiet
                fi
            done
            echo -e "${GREEN}  ✓ Old images deleted${NC}"
        else
            echo "  Skipped"
        fi
    elif [ "$IMAGE_COUNT" -gt "0" ]; then
        if confirm "Delete all custom images?"; then
            echo "$IMAGES" | while read -r img; do
                if [ -n "$img" ]; then
                    echo "  Deleting $img..."
                    gcloud compute images delete $img --quiet
                fi
            done
            echo -e "${GREEN}  ✓ All images deleted${NC}"
        else
            echo "  Skipped"
        fi
    fi
fi
echo ""

# 3. List persistent disks
echo -e "${YELLOW}3. Persistent Disks:${NC}"
echo ""

DISKS=$(gcloud compute disks list \
    --filter="zone~$REGION AND -users:*" \
    --format="value(name,zone)" 2>/dev/null)

if [ -z "$DISKS" ]; then
    echo -e "${GREEN}  ✓ No unattached disks${NC}"
else
    echo "Unattached disks:"
    gcloud compute disks list \
        --filter="zone~$REGION AND -users:*" \
        --format="table(name,zone,sizeGb,type.basename(),creationTimestamp.date())"
    echo ""

    if confirm "Delete unattached disks?"; then
        echo "$DISKS" | while IFS=$'\t' read -r name zone; do
            if [ -n "$name" ]; then
                echo "  Deleting disk $name in $zone..."
                gcloud compute disks delete $name --zone=$zone --quiet
            fi
        done
        echo -e "${GREEN}  ✓ Unattached disks deleted${NC}"
    else
        echo "  Skipped"
    fi
fi
echo ""

# 4. Check for snapshots
echo -e "${YELLOW}4. Disk Snapshots:${NC}"
echo ""

SNAPSHOTS=$(gcloud compute snapshots list --format="value(name)" 2>/dev/null)

if [ -z "$SNAPSHOTS" ]; then
    echo -e "${GREEN}  ✓ No snapshots found${NC}"
else
    echo "Existing snapshots:"
    gcloud compute snapshots list --format="table(name,diskSizeGb,creationTimestamp.date())"
    echo ""

    if confirm "Delete all snapshots?"; then
        echo "$SNAPSHOTS" | while read -r snap; do
            if [ -n "$snap" ]; then
                echo "  Deleting snapshot $snap..."
                gcloud compute snapshots delete $snap --quiet
            fi
        done
        echo -e "${GREEN}  ✓ Snapshots deleted${NC}"
    else
        echo "  Skipped"
    fi
fi
echo ""

# 5. Quota usage summary
echo -e "${YELLOW}5. Current Quota Usage:${NC}"
echo ""

gcloud compute regions describe $REGION \
    --format="table(
        quotas.filter(metric~'CPUS|NVIDIA_L4|DISKS_TOTAL_GB|IN_USE_ADDRESSES').metric,
        quotas.filter(metric~'CPUS|NVIDIA_L4|DISKS_TOTAL_GB|IN_USE_ADDRESSES').usage,
        quotas.filter(metric~'CPUS|NVIDIA_L4|DISKS_TOTAL_GB|IN_USE_ADDRESSES').limit
    )" 2>/dev/null
echo ""

# 6. Cost analysis
echo -e "${YELLOW}6. Billing & Cost Analysis:${NC}"
echo ""

BILLING_ACCOUNT=$(gcloud billing projects describe $PROJECT \
    --format="value(billingAccountName)" 2>/dev/null || echo "")

if [ -z "$BILLING_ACCOUNT" ]; then
    echo "  No billing account linked"
else
    echo "  Billing Account: $BILLING_ACCOUNT"
    echo ""
    echo "  Note: Detailed billing data may take 24-48 hours to appear"
    echo "  View costs at: https://console.cloud.google.com/billing?project=$PROJECT"
fi
echo ""

# 7. Service account cleanup
echo -e "${YELLOW}7. Service Accounts:${NC}"
echo ""

SERVICE_ACCOUNTS=$(gcloud iam service-accounts list \
    --filter="email~packer" \
    --format="value(email)" 2>/dev/null)

if [ -z "$SERVICE_ACCOUNTS" ]; then
    echo -e "${GREEN}  ✓ No Packer service accounts found${NC}"
else
    echo "Packer service accounts:"
    gcloud iam service-accounts list \
        --filter="email~packer" \
        --format="table(email,displayName)"
    echo ""
    echo "  Note: Service account keys should be deleted manually for security"
    echo "  Keep service account if you plan to rebuild images"
fi
echo ""

# Summary
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Cleanup Summary                                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Count remaining resources
REMAINING_INSTANCES=$(gcloud compute instances list --filter="zone~$REGION" --format="value(name)" | wc -l | tr -d ' ')
REMAINING_IMAGES=$(gcloud compute images list --filter="family~vault-cube" --format="value(name)" | wc -l | tr -d ' ')
REMAINING_DISKS=$(gcloud compute disks list --filter="zone~$REGION AND -users:*" --format="value(name)" | wc -l | tr -d ' ')

echo "Remaining resources:"
echo "  Instances: $REMAINING_INSTANCES"
echo "  Custom Images: $REMAINING_IMAGES"
echo "  Unattached Disks: $REMAINING_DISKS"
echo ""

if [ "$REMAINING_INSTANCES" -eq "0" ] && [ "$REMAINING_IMAGES" -le "1" ] && [ "$REMAINING_DISKS" -eq "0" ]; then
    echo -e "${GREEN}✓ Project is clean!${NC}"
else
    echo -e "${YELLOW}⚠ Some resources remain${NC}"
    echo "  Keep images if you plan to deploy test instances later"
    echo "  All stopped instances still incur disk storage costs"
fi
echo ""

echo -e "${BLUE}Additional Cleanup Options:${NC}"
echo ""
echo "  • View all resources: https://console.cloud.google.com/compute?project=$PROJECT"
echo "  • Check billing: https://console.cloud.google.com/billing?project=$PROJECT"
echo "  • Delete project entirely: ${RED}gcloud projects delete $PROJECT${NC}"
echo ""
echo -e "${YELLOW}Estimated monthly storage cost for $REMAINING_IMAGES image(s): ~\$${REMAINING_IMAGES}.00${NC}"
echo ""
