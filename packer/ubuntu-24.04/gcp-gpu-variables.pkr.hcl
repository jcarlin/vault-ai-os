# GCP-specific variables for GPU image builds
# Part of Vault Cube Golden Image - Epic 1a

variable "gcp_project_id" {
  type        = string
  description = "GCP project ID"
  default     = "vault-cube-gpu"
}

variable "gcp_zone" {
  type        = string
  description = "GCP zone for build instance (must support GPU accelerators)"
  default     = "us-central1-a"
  validation {
    condition     = can(regex("^us-central1-[a-c]$", var.gcp_zone))
    error_message = "Zone must be in us-central1 (a, b, or c) for optimal GPU availability."
  }
}

variable "gcp_source_image_family" {
  type        = string
  description = "Ubuntu source image family"
  default     = "ubuntu-2404-lts"
}

variable "gcp_source_image_project" {
  type        = string
  description = "Project containing source image (Canonical's Ubuntu project)"
  default     = "ubuntu-os-cloud"
}

variable "gcp_machine_type_build" {
  type        = string
  description = "Machine type for build instance (with GPU)"
  default     = "g2-standard-4"
  # Options:
  # - g2-standard-4:  4 vCPU, 16GB RAM, 1x L4 (Ada Lovelace) — cheapest
  # - g2-standard-8:  8 vCPU, 32GB RAM, 1x L4 (Ada Lovelace)
  # - g4-standard-4:  4 vCPU, 16GB RAM, 1x RTX PRO 6000 (Blackwell sm_120) — recommended for RTX 5090 validation
}

variable "gcp_gpu_type" {
  type        = string
  description = "GPU accelerator type for build instance"
  default     = "nvidia-l4"
  # Options:
  # - nvidia-l4:             Ada Lovelace (sm_89) — cheapest, good for workflow validation
  # - nvidia-rtx-pro-6000:   Blackwell (sm_120) — same arch as RTX 5090, best for full stack validation
  # - nvidia-tesla-a100:     Ampere (sm_80)
  validation {
    condition     = contains(["nvidia-l4", "nvidia-rtx-pro-6000", "nvidia-tesla-t4", "nvidia-tesla-a100"], var.gcp_gpu_type)
    error_message = "GPU type must be nvidia-l4, nvidia-rtx-pro-6000, nvidia-tesla-t4, or nvidia-tesla-a100."
  }
}

variable "gcp_gpu_count" {
  type        = number
  description = "Number of GPUs to attach to build instance"
  default     = 1
  validation {
    condition     = var.gcp_gpu_count >= 1 && var.gcp_gpu_count <= 8
    error_message = "GPU count must be between 1 and 8."
  }
}

variable "gcp_use_preemptible" {
  type        = bool
  description = "Use preemptible instances for 60-70% cost savings (may be terminated)"
  default     = true
}

variable "gcp_disk_size" {
  type        = number
  description = "Boot disk size in GB (minimum 50GB for CUDA/cuDNN)"
  default     = 100
  validation {
    condition     = var.gcp_disk_size >= 50
    error_message = "Disk size must be at least 50GB for GPU drivers and ML frameworks."
  }
}

variable "gcp_disk_type" {
  type        = string
  description = "Disk type (pd-standard: HDD, pd-balanced: SSD, pd-ssd: High-performance SSD)"
  default     = "pd-balanced"
  validation {
    condition     = contains(["pd-standard", "pd-balanced", "pd-ssd"], var.gcp_disk_type)
    error_message = "Disk type must be pd-standard, pd-balanced, or pd-ssd."
  }
}

variable "gcp_network" {
  type        = string
  description = "VPC network name (use 'default' for automatic setup)"
  default     = "default"
}

variable "gcp_subnetwork" {
  type        = string
  description = "VPC subnetwork name (leave empty for automatic)"
  default     = ""
}

variable "gcp_tags" {
  type        = list(string)
  description = "Network tags for firewall rules"
  default     = ["packer-build", "gpu-instance", "vault-cube"]
}

variable "gcp_image_family" {
  type        = string
  description = "Image family for grouping related images"
  default     = "vault-cube-gpu"
}

variable "gcp_image_name" {
  type        = string
  description = "Name for created image (timestamp automatically appended)"
  default     = "vault-cube-gpu-{{timestamp}}"
}

variable "gcp_image_description" {
  type        = string
  description = "Description for created image"
  default     = "Vault Cube GPU Golden Image - Ubuntu 24.04 LTS with NVIDIA drivers 570+, CUDA 12.8, Kernel 6.13+, PyTorch cu128, TensorFlow NGC, vLLM (RTX 5090 Ready)"
}

variable "gcp_image_labels" {
  type        = map(string)
  description = "Labels for created image (for organization and cost tracking)"
  default = {
    environment  = "production"
    project      = "vault-cube"
    epic         = "1a"
    cuda         = "12-8"
    kernel       = "6-13"
    pytorch      = "2-7-cu128"
    tensorflow   = "2-17-ngc"
    vllm         = "latest"
    created_by   = "packer"
    os           = "ubuntu-2404"
    target       = "rtx-5090-blackwell"
  }
}

variable "gcp_ssh_username" {
  type        = string
  description = "SSH username for build instance"
  default     = "packer"
}

variable "gcp_service_account_email" {
  type        = string
  description = "Service account email for build instance (created by setup-gcp.sh)"
  default     = ""
  # If empty, Packer will use: packer-gpu-builder@{project_id}.iam.gserviceaccount.com
}

variable "gcp_scopes" {
  type        = list(string)
  description = "OAuth scopes for service account"
  default = [
    "https://www.googleapis.com/auth/devstorage.full_control",
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/cloud-platform"
  ]
}

# GPU architecture detection for ansible
variable "nvidia_gpu_architecture" {
  type        = string
  description = "GPU architecture for NVIDIA driver selection"
  default     = "blackwell"
  # Options:
  # - blackwell:     RTX 5090, RTX PRO 6000, B200 (sm_120) — target architecture
  # - ada-lovelace:  RTX 4090, L4 (sm_89)
  # - ampere:        A100, RTX 3090 (sm_80)
}

variable "nvidia_expected_gpu_count" {
  type        = number
  description = "Expected number of GPUs for validation"
  default     = 1
}

# Build optimization
variable "ssh_timeout" {
  type        = string
  description = "SSH connection timeout"
  default     = "20m"
}

variable "ssh_handshake_attempts" {
  type        = number
  description = "Number of SSH handshake attempts"
  default     = 100
}

# Storage location for images
variable "gcp_image_storage_locations" {
  type        = list(string)
  description = "Storage locations for images (multi-region for redundancy)"
  default     = ["us"]
  # Options: ["us"], ["eu"], ["asia"], ["us", "eu"]
}
