#!/bin/bash
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Vault Cube GPU - GCP Environment Setup              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}✗ ERROR: gcloud CLI not found${NC}"
    echo ""
    echo "Please install Google Cloud SDK:"
    echo "  brew install --cask google-cloud-sdk"
    echo ""
    echo "After installation, add to your shell:"
    echo "  source \"\$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc\""
    echo "  source \"\$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc\""
    echo ""
    echo "Then reload your shell:"
    echo "  exec -l \$SHELL"
    exit 1
fi

echo -e "${GREEN}✓ gcloud CLI found: $(gcloud --version | head -1)${NC}"
echo ""

# Variables with defaults
PROJECT_ID=${GCP_PROJECT_ID:-vault-cube-gpu}
REGION=${GCP_REGION:-us-central1}
ZONE=${GCP_ZONE:-us-central1-a}
SERVICE_ACCOUNT_NAME="packer-gpu-builder"
KEY_DIR="$HOME/.gcp"
KEY_FILE="$KEY_DIR/packer-gpu-builder-key.json"

echo -e "${BLUE}Configuration:${NC}"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Zone: $ZONE"
echo "  Service Account: $SERVICE_ACCOUNT_NAME"
echo "  Key Directory: $KEY_DIR"
echo ""

read -p "Continue with these settings? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled"
    exit 0
fi
echo ""

# Step 1: Authenticate with gcloud
echo -e "${YELLOW}Step 1/10: Authenticating with GCP...${NC}"
if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    echo -e "${GREEN}✓ Already authenticated as: $ACTIVE_ACCOUNT${NC}"
else
    echo "Opening browser for authentication..."
    gcloud auth login
    echo -e "${GREEN}✓ Authentication complete${NC}"
fi
echo ""

# Step 2: Create or select project
echo -e "${YELLOW}Step 2/10: Setting up GCP project...${NC}"
if gcloud projects describe $PROJECT_ID &>/dev/null; then
    echo -e "${GREEN}✓ Project '$PROJECT_ID' already exists${NC}"
else
    echo "Creating new project: $PROJECT_ID"
    gcloud projects create $PROJECT_ID \
        --name="Vault Cube GPU Validation" \
        --set-as-default
    echo -e "${GREEN}✓ Project created${NC}"
fi

# Set as default project
gcloud config set project $PROJECT_ID
echo -e "${GREEN}✓ Default project set to: $PROJECT_ID${NC}"
echo ""

# Step 3: Link billing account
echo -e "${YELLOW}Step 3/10: Linking billing account...${NC}"
BILLING_ENABLED=$(gcloud billing projects describe $PROJECT_ID --format="value(billingEnabled)" 2>/dev/null || echo "false")

if [ "$BILLING_ENABLED" = "True" ]; then
    echo -e "${GREEN}✓ Billing already enabled${NC}"
else
    echo ""
    echo "Available billing accounts:"
    gcloud billing accounts list --format="table(name,displayName,open)"
    echo ""

    # Try to get billing accounts
    BILLING_ACCOUNTS=$(gcloud billing accounts list --filter="open=true" --format="value(name)" | wc -l | tr -d ' ')

    if [ "$BILLING_ACCOUNTS" -eq "0" ]; then
        echo -e "${RED}✗ No active billing accounts found${NC}"
        echo ""
        echo "Please set up billing:"
        echo "  1. Visit: https://console.cloud.google.com/billing"
        echo "  2. Create or link a billing account"
        echo "  3. Re-run this script"
        exit 1
    elif [ "$BILLING_ACCOUNTS" -eq "1" ]; then
        BILLING_ACCOUNT=$(gcloud billing accounts list --filter="open=true" --format="value(name)" | head -1)
        echo "Using billing account: $BILLING_ACCOUNT"
    else
        read -p "Enter billing account ID (0XXXXX-XXXXXX-XXXXXX): " BILLING_ACCOUNT
    fi

    gcloud billing projects link $PROJECT_ID \
        --billing-account=$BILLING_ACCOUNT
    echo -e "${GREEN}✓ Billing linked${NC}"
fi
echo ""

# Step 4: Enable required APIs
echo -e "${YELLOW}Step 4/10: Enabling required APIs...${NC}"
echo "  - Compute Engine API"
gcloud services enable compute.googleapis.com --quiet
echo "  - Cloud Storage API"
gcloud services enable storage.googleapis.com --quiet
echo "  - Cloud Billing Budgets API"
gcloud services enable billingbudgets.googleapis.com --quiet 2>/dev/null || echo "    (Budget API optional)"
echo -e "${GREEN}✓ APIs enabled${NC}"
echo ""

# Wait for API propagation
echo "Waiting for APIs to propagate (10 seconds)..."
sleep 10
echo ""

# Step 5: Set default region and zone
echo -e "${YELLOW}Step 5/10: Configuring default region and zone...${NC}"
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE
echo -e "${GREEN}✓ Region set to: $REGION${NC}"
echo -e "${GREEN}✓ Zone set to: $ZONE${NC}"
echo ""

# Step 6: Create service account
echo -e "${YELLOW}Step 6/10: Creating service account...${NC}"
SERVICE_ACCOUNT_EMAIL="$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"

if gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL &>/dev/null; then
    echo -e "${GREEN}✓ Service account already exists${NC}"
else
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --display-name="Packer GPU Image Builder" \
        --description="Service account for automated GPU image builds with Packer"
    echo -e "${GREEN}✓ Service account created${NC}"
fi
echo ""

# Step 7: Grant IAM roles
echo -e "${YELLOW}Step 7/10: Granting IAM roles...${NC}"
echo "  - Compute Instance Admin (v1)"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/compute.instanceAdmin.v1" \
    --quiet

echo "  - Service Account User"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/iam.serviceAccountUser" \
    --quiet

echo "  - Storage Admin"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/storage.admin" \
    --quiet

echo -e "${GREEN}✓ IAM roles granted${NC}"
echo ""

# Step 8: Create and download service account key
echo -e "${YELLOW}Step 8/10: Creating service account key...${NC}"
mkdir -p $KEY_DIR

if [ -f "$KEY_FILE" ]; then
    echo -e "${YELLOW}⚠ Key file already exists: $KEY_FILE${NC}"
    read -p "Overwrite existing key? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "$KEY_FILE"
    else
        echo "Keeping existing key"
        KEY_EXISTS=true
    fi
fi

if [ ! -f "$KEY_FILE" ]; then
    gcloud iam service-accounts keys create $KEY_FILE \
        --iam-account=$SERVICE_ACCOUNT_EMAIL
    chmod 600 $KEY_FILE
    echo -e "${GREEN}✓ Service account key created: $KEY_FILE${NC}"
else
    echo -e "${GREEN}✓ Using existing key: $KEY_FILE${NC}"
fi
echo ""

# Step 9: Configure environment variables
echo -e "${YELLOW}Step 9/10: Configuring environment variables...${NC}"

# Determine shell config file
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_RC="$HOME/.bashrc"
else
    SHELL_RC="$HOME/.profile"
fi

# Add to shell config if not already present
if ! grep -q "GOOGLE_APPLICATION_CREDENTIALS" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# GCP credentials for Vault Cube GPU project" >> "$SHELL_RC"
    echo "export GOOGLE_APPLICATION_CREDENTIALS=$KEY_FILE" >> "$SHELL_RC"
    echo -e "${GREEN}✓ Added to $SHELL_RC${NC}"
else
    echo -e "${GREEN}✓ Already configured in $SHELL_RC${NC}"
fi

# Set for current session
export GOOGLE_APPLICATION_CREDENTIALS=$KEY_FILE
echo -e "${GREEN}✓ Environment variable set for current session${NC}"
echo ""

# Step 10: Create SSH key
echo -e "${YELLOW}Step 10/10: Creating SSH key...${NC}"
SSH_KEY="$HOME/.ssh/gcp-vault-cube"

if [ ! -f "$SSH_KEY" ]; then
    ssh-keygen -t rsa -b 4096 -C "vault-cube-gpu" -f $SSH_KEY -N ""
    echo -e "${GREEN}✓ SSH key created: $SSH_KEY${NC}"
else
    echo -e "${GREEN}✓ SSH key already exists: $SSH_KEY${NC}"
fi

# Add SSH key to project metadata
echo "Adding SSH key to project metadata..."
gcloud compute project-info add-metadata \
    --metadata-from-file ssh-keys=<(echo "vaultadmin:$(cat $SSH_KEY.pub)") \
    --quiet 2>/dev/null || echo "  (SSH key already in metadata)"
echo -e "${GREEN}✓ SSH key configured${NC}"
echo ""

# Check GPU quota
echo -e "${BLUE}Checking GPU quota availability...${NC}"
QUOTA=$(gcloud compute regions describe $REGION \
    --format="value(quotas.filter(metric:nvidia_l4).limit)" 2>/dev/null || echo "0")

echo "  L4 GPU Quota in $REGION: $QUOTA"

if [ "$QUOTA" = "0" ] || [ -z "$QUOTA" ]; then
    echo -e "${RED}⚠ WARNING: No L4 GPU quota available${NC}"
    echo ""
    echo "To request GPU quota:"
    echo "  1. Visit: https://console.cloud.google.com/iam-admin/quotas?project=$PROJECT_ID"
    echo "  2. Filter by: 'L4 GPUs' and region '$REGION'"
    echo "  3. Select quota → Edit quotas"
    echo "  4. Request new limit: 4-8 GPUs"
    echo "  5. Justification: 'GPU-accelerated ML model training and validation'"
    echo "  6. Wait 1-2 business days for approval"
    echo ""
    read -p "Press Enter to continue (you can request quota later)..."
elif [ "$QUOTA" -lt "4" ]; then
    echo -e "${YELLOW}⚠ Limited quota ($QUOTA GPUs) - consider requesting increase for multi-GPU testing${NC}"
else
    echo -e "${GREEN}✓ Adequate quota ($QUOTA GPUs)${NC}"
fi
echo ""

# Summary
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Setup Complete!                                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
echo "  ✓ Project: $(gcloud config get-value project)"
echo "  ✓ Region: $(gcloud config get-value compute/region)"
echo "  ✓ Zone: $(gcloud config get-value compute/zone)"
echo "  ✓ Service Account: $SERVICE_ACCOUNT_EMAIL"
echo "  ✓ Service Account Key: $KEY_FILE"
echo "  ✓ SSH Key: $SSH_KEY"
echo "  ✓ L4 GPU Quota: $QUOTA GPUs"
echo ""
echo -e "${BLUE}Environment Variables:${NC}"
echo "  export GOOGLE_APPLICATION_CREDENTIALS=$KEY_FILE"
echo ""
echo -e "${YELLOW}Important: Reload your shell to apply environment variables${NC}"
echo "  exec -l \$SHELL"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Reload shell: ${GREEN}exec -l \$SHELL${NC}"
echo "  2. Verify setup: ${GREEN}./scripts/check-gcp-quotas.sh${NC}"
echo "  3. Review plan: ${GREEN}cat docs/gcp-validate-gpu-plan.md${NC}"
echo "  4. Build GPU image: ${GREEN}cd packer && packer build -only=cloud-gpu-gcp .${NC}"
echo ""
echo -e "${YELLOW}Cost Estimate: \$3-5 for complete testing (FREE with \$300 GCP credit)${NC}"
echo ""
