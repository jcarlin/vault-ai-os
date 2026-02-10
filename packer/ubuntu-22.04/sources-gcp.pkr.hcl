# GCP googlecompute builder for GPU instances
# Part of Vault Cube Golden Image - Epic 1a

locals {
  # Auto-generate service account email if not provided
  gcp_service_account = var.gcp_service_account_email != "" ? var.gcp_service_account_email : "packer-gpu-builder@${var.gcp_project_id}.iam.gserviceaccount.com"

  # Timestamp for unique image names
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "googlecompute" "ubuntu-2204-gpu" {
  # ============================================================================
  # Project and Authentication
  # ============================================================================
  project_id            = var.gcp_project_id
  service_account_email = local.gcp_service_account
  scopes                = var.gcp_scopes

  # ============================================================================
  # Source Image
  # ============================================================================
  source_image_family     = var.gcp_source_image_family
  source_image_project_id = [var.gcp_source_image_project]

  # ============================================================================
  # Build Instance Configuration
  # ============================================================================
  zone         = var.gcp_zone
  machine_type = var.gcp_machine_type_build

  # GPU Configuration
  # CRITICAL: L4 GPU for Ada Lovelace architecture (RTX 40/50 equivalent)
  accelerator_type  = var.gcp_gpu_type
  accelerator_count = var.gcp_gpu_count

  # REQUIRED: GPU instances must use TERMINATE maintenance policy
  # Cannot live migrate with GPU attached
  on_host_maintenance = "TERMINATE"

  # ============================================================================
  # Disk Configuration
  # ============================================================================
  disk_size = var.gcp_disk_size
  disk_type = var.gcp_disk_type

  # ============================================================================
  # Network Configuration
  # ============================================================================
  network    = var.gcp_network
  subnetwork = var.gcp_subnetwork
  tags       = var.gcp_tags

  # External IP required for package downloads during build
  omit_external_ip = false
  use_internal_ip  = false

  # ============================================================================
  # Cost Optimization
  # ============================================================================
  # Preemptible instances provide 60-70% cost savings
  # Safe for Packer builds (can be retried if terminated)
  preemptible = var.gcp_use_preemptible

  # ============================================================================
  # SSH Configuration
  # ============================================================================
  ssh_username = var.gcp_ssh_username
  ssh_timeout  = var.ssh_timeout

  # Ubuntu 22.04 may take longer to become ready
  ssh_handshake_attempts = var.ssh_handshake_attempts

  # ============================================================================
  # Output Image Configuration
  # ============================================================================
  image_name              = var.gcp_image_name
  image_family            = var.gcp_image_family
  image_description       = var.gcp_image_description
  image_labels            = var.gcp_image_labels
  image_storage_locations = var.gcp_image_storage_locations

  # ============================================================================
  # Instance Metadata
  # ============================================================================
  metadata = {
    # Disable OS Login (use project SSH keys instead)
    enable-oslogin = "FALSE"

    # Allow project-wide SSH keys
    block-project-ssh-keys = "FALSE"

    # Startup script (optional - can add custom initialization)
    startup-script = <<-EOF
      #!/bin/bash
      # Log startup
      echo "Packer build instance starting - $(date)" | tee -a /var/log/packer-startup.log

      # Verify GPU presence
      if lspci | grep -i nvidia; then
        echo "GPU detected: $(lspci | grep -i nvidia)" | tee -a /var/log/packer-startup.log
      else
        echo "WARNING: No NVIDIA GPU detected" | tee -a /var/log/packer-startup.log
      fi
    EOF

    # Build metadata for tracking
    packer-build        = "true"
    packer-builder      = "googlecompute"
    vault-cube-epic     = "1a"
    vault-cube-task     = "1a.8-nvidia-drivers"
    build-timestamp     = local.timestamp
  }

  # ============================================================================
  # Communicator Settings
  # ============================================================================
  communicator = "ssh"

  # Disable agent forwarding for security
  ssh_agent_auth = false

  # ============================================================================
  # Advanced Options
  # ============================================================================
  # Disable shielded VM features for GPU compatibility
  enable_secure_boot          = false
  enable_vtpm                 = false
  enable_integrity_monitoring = false

  # Accelerator-optimized image features
  image_guest_os_features = [
    "UEFI_COMPATIBLE",
    "VIRTIO_SCSI_MULTIQUEUE",
    "GVNIC"
  ]
}
