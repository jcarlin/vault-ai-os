# QEMU MCP Server

An MCP (Model Context Protocol) server that wraps QEMU commands for disk image management and VM operations. Designed for the Vault Cube Golden Image project to enable Claude Code to manage test VMs and automate bare metal deployment workflows.

## Features

### Image Operations (qemu-img)

| Tool | Description |
|------|-------------|
| `qemu_image_info` | Get detailed image info (format, size, backing file) |
| `qemu_image_convert` | Convert between formats (raw, qcow2, vmdk, vdi, vhdx) |
| `qemu_create_overlay` | Create COW overlay for testing without modifying original |
| `qemu_image_resize` | Resize disk image (+10G, -5G, 100G) |

### VM Operations (qemu-system)

| Tool | Description |
|------|-------------|
| `qemu_boot_vm` | Boot image in QEMU with auto-detected accelerator |
| `qemu_list_vms` | List running QEMU processes |
| `qemu_stop_vm` | Stop a running VM by PID or SSH port |
| `qemu_vm_status` | Check if VM is running and SSH accessible |

## Prerequisites

- Python 3.10+
- QEMU installed:
  - macOS: `brew install qemu`
  - Ubuntu/Debian: `apt install qemu-system-x86 qemu-utils`
  - Fedora/RHEL: `dnf install qemu-system-x86 qemu-img`

## Installation

```bash
cd tools/qemu-mcp
pip install -e .
```

## Adding to Claude Code

### Project Scope (recommended)

```bash
claude mcp add --transport stdio --scope project qemu -- python -m qemu_mcp.server
```

This creates `.mcp.json` in the project root:

```json
{
  "mcpServers": {
    "qemu": {
      "type": "stdio",
      "command": "python",
      "args": ["-m", "qemu_mcp.server"]
    }
  }
}
```

### User Scope

```bash
claude mcp add --transport stdio --scope user qemu -- python -m qemu_mcp.server
```

## Verification

After adding the server, verify it's connected:

```
/mcp
```

You should see `qemu` listed with 8 tools.

## Usage Examples

### Get Image Information

```
User: Get info about the baremetal image
Claude: [calls qemu_image_info with image_path]

Result:
{
  "filename": "vault-cube.qcow2",
  "format": "qcow2",
  "virtual-size": 107374182400,
  "virtual-size-human": "100.0 GB",
  "actual-size": 4521984000,
  "actual-size-human": "4.2 GB"
}
```

### Boot VM for Testing

```
User: Boot the golden image for testing on port 2222
Claude: [calls qemu_boot_vm with ssh_port=2222]

Result:
{
  "success": true,
  "pid": 12345,
  "ssh_port": 2222,
  "accelerator": "hvf",
  "ssh_command": "ssh -p 2222 vaultadmin@localhost",
  "note": "VM booting in background. Wait ~30-60s for SSH."
}
```

### Create Test Overlay

```
User: Create a test overlay so I can experiment without changing the original
Claude: [calls qemu_create_overlay]

Result:
{
  "success": true,
  "overlay_path": "/path/to/test-overlay.qcow2",
  "backing_file": "/path/to/original.qcow2",
  "note": "Changes to overlay will not affect the base image"
}
```

### Convert Image Format

```
User: Convert the VMDK to raw format for bare metal deployment
Claude: [calls qemu_image_convert with output_format="raw"]

Result:
{
  "success": true,
  "output_path": "/path/to/image.raw",
  "output_format": "raw",
  "output_size": "100.0 GB"
}
```

### Check VM Status

```
User: Is the test VM ready?
Claude: [calls qemu_vm_status with ssh_port=2222]

Result:
{
  "ssh_port": 2222,
  "status": "running",
  "process_running": true,
  "ssh_accessible": true,
  "message": "VM is running and SSH accessible on port 2222"
}
```

## Platform-Specific Notes

### macOS (Apple Silicon)

- Uses HVF (Hypervisor.framework) for acceleration
- Requires QEMU 6.2+ for Apple Silicon support
- OVMF firmware auto-detected from Homebrew paths

### macOS (Intel)

- Uses HVF acceleration
- Full x86_64 virtualization support

### Linux

- Uses KVM if `/dev/kvm` is accessible
- User must be in `kvm` group: `sudo usermod -aG kvm $USER`
- Falls back to TCG (software emulation) if KVM unavailable

## Development

### Running Tests

```bash
cd tools/qemu-mcp
pip install -e ".[dev]"
pytest
```

### Manual Server Testing

```bash
python -m qemu_mcp.server
```

The server communicates via JSON-RPC over stdio. You can test with:

```bash
echo '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}' | python -m qemu_mcp.server
```

## Troubleshooting

### "qemu-img not found"

Install QEMU:
- macOS: `brew install qemu`
- Linux: `apt install qemu-utils` or `dnf install qemu-img`

### "Port already in use"

Another VM is using that SSH port. Either:
- Stop the existing VM: `qemu_stop_vm(ssh_port=2222)`
- Use a different port: `qemu_boot_vm(..., ssh_port=2223)`

### "Permission denied" on Linux KVM

Add your user to the kvm group:
```bash
sudo usermod -aG kvm $USER
# Log out and back in
```

### VM boots but SSH doesn't connect

- Wait longer (30-60 seconds for boot)
- Check status: `qemu_vm_status(ssh_port=2222)`
- Ensure the image has SSH server installed and enabled
- Verify correct credentials (default: vaultadmin/vaultadmin)
