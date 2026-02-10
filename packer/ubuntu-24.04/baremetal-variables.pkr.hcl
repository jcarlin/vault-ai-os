# Bare Metal Variables for Vault Cube Physical Hardware
# Optimized for 4x RTX 5090, 256GB RAM, 2TB NVMe SSD

variable "baremetal_output_dir" {
  type        = string
  description = "Output directory for bare metal images"
  default     = "output-baremetal-2"
}

variable "baremetal_output_format" {
  type        = string
  description = "Output format: raw (disk image), qcow2 (compressed), iso (bootable)"
  default     = "raw"
  validation {
    condition     = contains(["raw", "qcow2", "iso"], var.baremetal_output_format)
    error_message = "Format must be raw, qcow2, or iso."
  }
}

variable "baremetal_disk_size" {
  type        = string
  description = "Boot disk size (matching Vault Cube 2TB NVMe)"
  default     = "2000G"
}

variable "baremetal_cpus" {
  type        = number
  description = "CPU count (matching Vault Cube specs)"
  default     = 32
}

variable "baremetal_memory" {
  type        = number
  description = "RAM in MB (matching Vault Cube 256GB)"
  default     = 262144  # 256GB in MB
}

variable "baremetal_accelerator" {
  type        = string
  description = "QEMU accelerator (kvm for Linux/WSL, hvf for macOS, tcg for fallback)"
  default     = "kvm"
  validation {
    condition     = contains(["kvm", "hvf", "tcg"], var.baremetal_accelerator)
    error_message = "Accelerator must be kvm, hvf, or tcg."
  }
}

variable "baremetal_headless" {
  type        = bool
  description = "Run QEMU in headless mode (no GUI)"
  default     = true
}

variable "baremetal_iso_target_extension" {
  type        = string
  description = "Extension for ISO target (iso or img)"
  default     = "iso"
}

variable "baremetal_use_backing_file" {
  type        = bool
  description = "Use backing file for incremental builds (faster, less space)"
  default     = false
}

variable "baremetal_disk_interface" {
  type        = string
  description = "Disk interface type (virtio-scsi for best performance)"
  default     = "virtio-scsi"
}

variable "baremetal_net_device" {
  type        = string
  description = "Network device type (virtio-net for best performance)"
  default     = "virtio-net"
}

variable "baremetal_qemu_binary" {
  type        = string
  description = "QEMU binary path (auto-detect if empty)"
  default     = ""
}

variable "baremetal_vm_name" {
  type        = string
  description = "VM name for QEMU build"
  default     = "vault-cube-baremetal"
}

# GPU Configuration for Physical Hardware
variable "baremetal_gpu_count" {
  type        = number
  description = "Number of RTX 5090 GPUs in Vault Cube"
  default     = 4
}

variable "baremetal_gpu_architecture" {
  type        = string
  description = "GPU architecture (blackwell for RTX 5090)"
  default     = "blackwell"
}

variable "baremetal_cuda_version" {
  type        = string
  description = "CUDA version for RTX 5090"
  default     = "12.8"
}

variable "baremetal_cudnn_version" {
  type        = string
  description = "cuDNN version"
  default     = "9.7.1"
}

variable "baremetal_kernel_version" {
  type        = string
  description = "Target kernel version (6.13+ for RTX 5090)"
  default     = "6.13"
}

# Build Optimization
variable "baremetal_ssh_timeout" {
  type        = string
  description = "SSH connection timeout"
  default     = "30m"
}

variable "baremetal_boot_wait" {
  type        = string
  description = "Time to wait before sending boot command"
  default     = "10s"
}

variable "baremetal_shutdown_timeout" {
  type        = string
  description = "Time to wait for graceful shutdown"
  default     = "15m"
}
