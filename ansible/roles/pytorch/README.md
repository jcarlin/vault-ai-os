# Ansible Role: pytorch

Installs PyTorch 2.x with CUDA support for multi-GPU deep learning.

## Description

Installs PyTorch with CUDA 12.4 support using pip. Supports multi-GPU configurations with DistributedDataParallel (DDP).

## Requirements

- Python 3.12+
- NVIDIA drivers with CUDA 12.4+
- pip

## Variables

```yaml
pytorch_version: "2.5.0"  # PyTorch version
pytorch_cuda_version: "cu124"  # CUDA version suffix
pytorch_install_torchvision: true
pytorch_install_torchaudio: true
```

## Example Playbook

```yaml
- hosts: gpu_servers
  become: yes
  roles:
    - nvidia
    - python
    - pytorch
```

## Testing

```bash
python3 -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}'); print(f'GPUs: {torch.cuda.device_count()}')"
```
