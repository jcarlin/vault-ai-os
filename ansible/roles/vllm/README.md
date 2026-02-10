# Ansible Role: vllm

Installs vLLM for high-performance LLM inference with multi-GPU support.

## Description

Installs vLLM (vLLM Inference Engine) for serving large language models with optimized inference.

## Requirements

- Python 3.12+
- PyTorch with CUDA support
- NVIDIA GPUs with 16GB+ VRAM

## Example Playbook

```yaml
- hosts: gpu_servers
  become: yes
  roles:
    - nvidia
    - python
    - pytorch
    - vllm
```

## Testing

```bash
python3 -c "from vllm import LLM; print('vLLM installed successfully')"
```
