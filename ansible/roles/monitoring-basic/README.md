# Ansible Role: monitoring-basic

Installs basic monitoring tools for GPU and system health.

## Description

Installs htop, iotop, nvtop, and configures nvidia-smi logging.

## Tools Installed

- htop - CPU/RAM monitoring
- iotop - Disk I/O monitoring
- nvtop - GPU monitoring (TUI)
- sysstat - System statistics
- lm-sensors - Hardware sensors

## Example Playbook

```yaml
- hosts: gpu_servers
  become: yes
  roles:
    - monitoring-basic
```
