# Ansible Role: nvidia-container-toolkit

Installs NVIDIA Container Toolkit to enable GPU access from Docker containers.

## Description

This role configures Docker to use NVIDIA GPUs by installing the NVIDIA Container Toolkit and configuring the Docker daemon with the NVIDIA runtime.

## Requirements

- Docker installed (`docker` role)
- NVIDIA drivers installed (`nvidia` role)
- Ubuntu 24.04 LTS

## Dependencies

- docker
- nvidia

## Example Playbook

```yaml
- hosts: gpu_servers
  become: yes
  roles:
    - nvidia
    - docker
    - nvidia-container-toolkit
```

## Testing

```bash
# Test Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi
```
