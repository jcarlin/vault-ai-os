# Ansible Role: tensorflow

Installs TensorFlow 2.x with CUDA support for multi-GPU deep learning.

## Description

Installs TensorFlow with CUDA 12.4 support. Compatible with Python 3.12.

## Requirements

- Python 3.12+
- NVIDIA drivers with CUDA 12.4+
- cuDNN 9.x

## Variables

```yaml
tensorflow_version: "2.16.1"  # TensorFlow version
```

## Example Playbook

```yaml
- hosts: gpu_servers
  become: yes
  roles:
    - nvidia
    - python
    - tensorflow
```

## Testing

```bash
python3 -c "import tensorflow as tf; print(f'TensorFlow: {tf.__version__}'); print(f'GPUs: {len(tf.config.list_physical_devices(\"GPU\"))}')"
```
