#!/bin/bash
set -e

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT=$(gcloud config get-value project 2>/dev/null)
ZONE=${GCP_ZONE:-$(gcloud config get-value compute/zone 2>/dev/null)}
INSTANCE_NAME=${INSTANCE_NAME:-vault-cube-gpu-test-$(date +%Y%m%d-%H%M)}
MACHINE_TYPE=${MACHINE_TYPE:-g2-standard-8}
GPU_TYPE="nvidia-l4"
GPU_COUNT=1
IMAGE_FAMILY="vault-cube-gpu"
DISK_SIZE=100
PREEMPTIBLE=${PREEMPTIBLE:-true}

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Launching GCP GPU Test Instance                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Instance Name: $INSTANCE_NAME"
echo "  Machine Type: $MACHINE_TYPE"
echo "  GPU: $GPU_COUNT x $GPU_TYPE (Ada Lovelace - RTX 40/50 equivalent)"
echo "  Image Family: $IMAGE_FAMILY"
echo "  Zone: $ZONE"
echo "  Disk Size: ${DISK_SIZE}GB"
echo "  Preemptible: $PREEMPTIBLE (60-70% cost savings)"
echo ""

# Find latest image from family
echo "Looking for latest image in family '$IMAGE_FAMILY'..."
IMAGE=$(gcloud compute images list \
    --filter="family=$IMAGE_FAMILY" \
    --sort-by=~creationTimestamp \
    --limit=1 \
    --format="value(name)" 2>/dev/null)

if [ -z "$IMAGE" ]; then
    echo -e "${RED}✗ ERROR: No image found in family '$IMAGE_FAMILY'${NC}"
    echo ""
    echo "Build the image first:"
    echo "  cd packer"
    echo "  packer build -only=cloud-gpu-gcp ubuntu-22.04-demo-box.pkr.hcl"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Found image: $IMAGE${NC}"
IMAGE_CREATED=$(gcloud compute images describe $IMAGE --format="value(creationTimestamp)")
echo "  Created: $IMAGE_CREATED"
echo ""

# Calculate estimated cost
if [ "$PREEMPTIBLE" = "true" ]; then
    HOURLY_COST="0.48"
else
    HOURLY_COST="1.21"
fi

echo -e "${YELLOW}Estimated Cost:${NC}"
echo "  \$${HOURLY_COST}/hour"
echo "  ~\$$(echo "$HOURLY_COST * 6" | bc) for 6 hours of testing"
echo ""

read -p "Continue with instance creation? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi
echo ""

# Build instance creation command
CMD="gcloud compute instances create $INSTANCE_NAME \
    --project=$PROJECT \
    --zone=$ZONE \
    --machine-type=$MACHINE_TYPE \
    --accelerator=type=$GPU_TYPE,count=$GPU_COUNT \
    --image=$IMAGE \
    --boot-disk-size=${DISK_SIZE}GB \
    --boot-disk-type=pd-balanced \
    --maintenance-policy=TERMINATE \
    --metadata=enable-oslogin=FALSE,shutdown-script='echo \"Auto-shutdown in 2 hours\"; shutdown -h +120' \
    --tags=gpu-instance,packer-build"

if [ "$PREEMPTIBLE" = "true" ]; then
    CMD="$CMD --preemptible"
fi

# Create instance
echo "Creating instance '$INSTANCE_NAME'..."
echo ""
eval $CMD

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to create instance${NC}"
    exit 1
fi

# Wait for instance to be ready
echo ""
echo "Waiting for instance to be ready (may take 30-60 seconds)..."
for i in {1..30}; do
    STATUS=$(gcloud compute instances describe $INSTANCE_NAME \
        --zone=$ZONE \
        --format="value(status)" 2>/dev/null || echo "UNKNOWN")

    if [ "$STATUS" = "RUNNING" ]; then
        echo -e "${GREEN}✓ Instance is RUNNING${NC}"
        break
    fi

    echo -n "."
    sleep 2
done
echo ""

# Get instance details
EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME \
    --zone=$ZONE \
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)

INTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME \
    --zone=$ZONE \
    --format="value(networkInterfaces[0].networkIP)" 2>/dev/null)

# Wait additional time for SSH to be ready
echo "Waiting for SSH to be ready (30 seconds)..."
sleep 30

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Instance Created Successfully!                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Instance Details:${NC}"
echo "  Name: $INSTANCE_NAME"
echo "  Zone: $ZONE"
echo "  Machine Type: $MACHINE_TYPE"
echo "  GPU: $GPU_COUNT x $GPU_TYPE"
echo "  External IP: $EXTERNAL_IP"
echo "  Internal IP: $INTERNAL_IP"
echo "  Preemptible: $PREEMPTIBLE"
echo "  Auto-shutdown: 2 hours"
echo ""

echo -e "${BLUE}Quick Commands:${NC}"
echo ""
echo -e "${YELLOW}1. SSH into instance:${NC}"
echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo ""

echo -e "${YELLOW}2. Check GPU status:${NC}"
echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command='nvidia-smi'"
echo ""

echo -e "${YELLOW}3. Run validation script:${NC}"
echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command='bash /home/vaultadmin/scripts/validate-gpus.sh'"
echo ""

echo -e "${YELLOW}4. Test PyTorch:${NC}"
echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command='python3 /home/vaultadmin/scripts/test-pytorch-ddp.py'"
echo ""

echo -e "${YELLOW}5. Monitor GPU:${NC}"
echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command='watch -n 1 nvidia-smi'"
echo ""

echo -e "${YELLOW}6. Stop instance (preserve disk):${NC}"
echo "  gcloud compute instances stop $INSTANCE_NAME --zone=$ZONE"
echo ""

echo -e "${YELLOW}7. Delete instance:${NC}"
echo "  gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE"
echo ""

echo -e "${BLUE}Management:${NC}"
echo ""
echo -e "${YELLOW}View in console:${NC}"
echo "  https://console.cloud.google.com/compute/instances?project=$PROJECT"
echo ""

echo -e "${YELLOW}Get instance info:${NC}"
echo "  gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE"
echo ""

echo -e "${YELLOW}SSH and run all validation tests:${NC}"
cat << 'SCRIPT_EOF' > /tmp/run-validation.sh
#!/bin/bash
echo "=== GPU Validation Suite ==="
echo ""

echo "1. GPU Detection:"
nvidia-smi
echo ""

echo "2. CUDA Version:"
nvcc --version
echo ""

echo "3. PyTorch CUDA:"
python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'GPU count: {torch.cuda.device_count()}')"
echo ""

echo "4. TensorFlow GPU:"
python3 -c "import tensorflow as tf; print(f'GPU devices: {len(tf.config.list_physical_devices(\"GPU\"))}')"
echo ""

echo "5. Running comprehensive validation..."
bash /home/vaultadmin/scripts/validate-gpus.sh
SCRIPT_EOF

echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE < /tmp/run-validation.sh"
echo ""

echo -e "${GREEN}Instance ready for testing!${NC}"
echo ""
