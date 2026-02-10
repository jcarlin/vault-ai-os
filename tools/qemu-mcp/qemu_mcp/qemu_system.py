"""
Wrapper functions for qemu-system-x86_64 commands.

Provides VM operations: boot, list, stop, status.
"""

import asyncio
import os
import platform
import shutil
import signal
import socket
from pathlib import Path
from typing import Optional


# Track spawned VMs by SSH port
_running_vms: dict[int, int] = {}  # ssh_port -> pid


def get_qemu_system_path() -> str:
    """Find qemu-system-x86_64 executable."""
    path = shutil.which("qemu-system-x86_64")
    if not path:
        raise FileNotFoundError(
            "qemu-system-x86_64 not found. Install QEMU: brew install qemu (macOS) or apt install qemu-system-x86 (Linux)"
        )
    return path


def detect_accelerator() -> str:
    """Detect the best available hardware accelerator."""
    system = platform.system()

    if system == "Darwin":
        # macOS: use Hypervisor.framework
        return "hvf"
    elif system == "Linux":
        # Linux: check for KVM
        if os.path.exists("/dev/kvm") and os.access("/dev/kvm", os.R_OK | os.W_OK):
            return "kvm"
    # Fallback to software emulation
    return "tcg"


def is_port_in_use(port: int) -> bool:
    """Check if a TCP port is in use."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(("127.0.0.1", port)) == 0


async def boot_vm(
    image_path: str,
    memory: str = "4G",
    cpus: int = 2,
    ssh_port: int = 2222,
    background: bool = True,
    extra_args: Optional[list[str]] = None,
) -> dict:
    """
    Boot a disk image in QEMU for testing.

    Args:
        image_path: Path to the disk image
        memory: RAM allocation (e.g., "4G", "8192M")
        cpus: Number of CPU cores
        ssh_port: Host port to forward to guest SSH (port 22)
        background: Run in background (True) or foreground (False)
        extra_args: Additional QEMU arguments

    Returns:
        Dictionary with VM boot info
    """
    path = Path(image_path).expanduser().resolve()
    if not path.exists():
        raise FileNotFoundError(f"Image not found: {image_path}")

    # Check if port is already in use
    if is_port_in_use(ssh_port):
        raise RuntimeError(
            f"Port {ssh_port} is already in use. Choose a different ssh_port or stop the existing VM."
        )

    qemu = get_qemu_system_path()
    accel = detect_accelerator()

    cmd = [
        qemu,
        "-machine", f"type=q35,accel={accel}",
        "-cpu", "host" if accel in ("kvm", "hvf") else "qemu64",
        "-m", memory,
        "-smp", str(cpus),
        "-drive", f"file={path},format=qcow2,if=virtio",
        "-netdev", f"user,id=net0,hostfwd=tcp::{ssh_port}-:22",
        "-device", "virtio-net-pci,netdev=net0",
        "-display", "none",
        "-serial", "mon:stdio" if not background else "null",
    ]

    # Add UEFI firmware for modern images
    # Check common locations for OVMF
    ovmf_paths = [
        "/opt/homebrew/share/qemu/edk2-x86_64-code.fd",  # macOS arm64 homebrew
        "/usr/local/share/qemu/edk2-x86_64-code.fd",    # macOS x86 homebrew
        "/usr/share/OVMF/OVMF_CODE.fd",                  # Debian/Ubuntu
        "/usr/share/edk2/ovmf/OVMF_CODE.fd",            # Fedora/RHEL
    ]
    for ovmf in ovmf_paths:
        if os.path.exists(ovmf):
            cmd.extend(["-bios", ovmf])
            break

    if extra_args:
        cmd.extend(extra_args)

    if background:
        # Daemonize by running without stdin/stdout connection
        cmd.extend(["-daemonize", "-pidfile", f"/tmp/qemu-vm-{ssh_port}.pid"])

        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.PIPE,
        )
        _, stderr = await process.communicate()

        if process.returncode != 0:
            raise RuntimeError(f"Failed to start VM: {stderr.decode()}")

        # Read PID from file
        pid_file = Path(f"/tmp/qemu-vm-{ssh_port}.pid")
        if pid_file.exists():
            pid = int(pid_file.read_text().strip())
            _running_vms[ssh_port] = pid
        else:
            pid = None

        return {
            "success": True,
            "image_path": str(path),
            "pid": pid,
            "ssh_port": ssh_port,
            "accelerator": accel,
            "memory": memory,
            "cpus": cpus,
            "ssh_command": f"ssh -p {ssh_port} vaultadmin@localhost",
            "note": "VM booting in background. Wait ~30-60s for SSH to become available.",
        }
    else:
        # Foreground mode - just return the command to run
        return {
            "success": True,
            "mode": "foreground",
            "command": " ".join(cmd),
            "note": "Run this command manually in a terminal for interactive use.",
        }


async def list_vms() -> dict:
    """
    List running QEMU VMs.

    Returns:
        Dictionary with list of running VMs
    """
    import subprocess

    # Find QEMU processes
    try:
        result = subprocess.run(
            ["pgrep", "-fl", "qemu-system"],
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        # pgrep not available, try ps
        result = subprocess.run(
            ["ps", "aux"],
            capture_output=True,
            text=True,
        )
        lines = [l for l in result.stdout.split("\n") if "qemu-system" in l and "grep" not in l]
        processes = []
        for line in lines:
            parts = line.split()
            if len(parts) >= 2:
                pid = parts[1]
                # Extract SSH port if present
                ssh_port = _extract_ssh_port(line)
                processes.append({
                    "pid": int(pid),
                    "ssh_port": ssh_port,
                    "command_snippet": " ".join(parts[10:])[:100] + "...",
                })
        return {"vms": processes, "count": len(processes)}

    if result.returncode != 0 and not result.stdout:
        return {"vms": [], "count": 0}

    processes = []
    for line in result.stdout.strip().split("\n"):
        if not line:
            continue
        parts = line.split(maxsplit=1)
        if len(parts) >= 1:
            pid = int(parts[0])
            cmd = parts[1] if len(parts) > 1 else ""
            ssh_port = _extract_ssh_port(cmd)
            processes.append({
                "pid": pid,
                "ssh_port": ssh_port,
                "command_snippet": cmd[:100] + "..." if len(cmd) > 100 else cmd,
            })

    return {"vms": processes, "count": len(processes)}


def _extract_ssh_port(cmd: str) -> Optional[int]:
    """Extract SSH port from QEMU command line."""
    import re
    match = re.search(r"hostfwd=tcp::(\d+)-:22", cmd)
    if match:
        return int(match.group(1))
    return None


async def stop_vm(pid: Optional[int] = None, ssh_port: Optional[int] = None) -> dict:
    """
    Stop a running QEMU VM.

    Args:
        pid: Process ID of the VM
        ssh_port: SSH port of the VM (alternative to pid)

    Returns:
        Dictionary with stop result
    """
    if pid is None and ssh_port is None:
        raise ValueError("Must provide either pid or ssh_port")

    # If ssh_port provided, find PID from pid file
    if pid is None and ssh_port is not None:
        pid_file = Path(f"/tmp/qemu-vm-{ssh_port}.pid")
        if pid_file.exists():
            pid = int(pid_file.read_text().strip())
        elif ssh_port in _running_vms:
            pid = _running_vms[ssh_port]
        else:
            # Try to find from process list
            vms = await list_vms()
            for vm in vms.get("vms", []):
                if vm.get("ssh_port") == ssh_port:
                    pid = vm["pid"]
                    break

    if pid is None:
        raise RuntimeError(f"Could not find VM with ssh_port {ssh_port}")

    try:
        # Send SIGTERM for graceful shutdown
        os.kill(pid, signal.SIGTERM)

        # Wait a moment, then check if still running
        await asyncio.sleep(2)

        try:
            os.kill(pid, 0)  # Check if process exists
            # Still running, force kill
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass  # Process already terminated

        # Clean up PID file
        if ssh_port:
            pid_file = Path(f"/tmp/qemu-vm-{ssh_port}.pid")
            if pid_file.exists():
                pid_file.unlink()
            if ssh_port in _running_vms:
                del _running_vms[ssh_port]

        return {
            "success": True,
            "pid": pid,
            "ssh_port": ssh_port,
            "message": "VM stopped successfully",
        }

    except ProcessLookupError:
        return {
            "success": False,
            "pid": pid,
            "error": "Process not found - VM may have already stopped",
        }
    except PermissionError:
        return {
            "success": False,
            "pid": pid,
            "error": "Permission denied - cannot stop this process",
        }


async def vm_status(ssh_port: int, timeout: int = 5) -> dict:
    """
    Check if a VM is running and SSH is accessible.

    Args:
        ssh_port: SSH port to check
        timeout: Connection timeout in seconds

    Returns:
        Dictionary with VM status
    """
    result = {
        "ssh_port": ssh_port,
        "port_open": False,
        "ssh_accessible": False,
        "process_running": False,
    }

    # Check if port is open
    result["port_open"] = is_port_in_use(ssh_port)

    # Check if QEMU process exists
    pid_file = Path(f"/tmp/qemu-vm-{ssh_port}.pid")
    if pid_file.exists():
        try:
            pid = int(pid_file.read_text().strip())
            os.kill(pid, 0)  # Check if process exists
            result["process_running"] = True
            result["pid"] = pid
        except (ProcessLookupError, ValueError):
            result["process_running"] = False

    # Try SSH connection test
    if result["port_open"]:
        try:
            proc = await asyncio.create_subprocess_exec(
                "ssh",
                "-o", "StrictHostKeyChecking=no",
                "-o", "UserKnownHostsFile=/dev/null",
                "-o", f"ConnectTimeout={timeout}",
                "-o", "BatchMode=yes",
                "-p", str(ssh_port),
                "localhost",
                "echo", "ok",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            )
            stdout, _ = await asyncio.wait_for(
                proc.communicate(), timeout=timeout + 2
            )
            result["ssh_accessible"] = proc.returncode == 0
        except (asyncio.TimeoutError, FileNotFoundError):
            result["ssh_accessible"] = False

    # Determine overall status
    if result["process_running"] and result["ssh_accessible"]:
        result["status"] = "running"
        result["message"] = f"VM is running and SSH accessible on port {ssh_port}"
    elif result["process_running"] and result["port_open"]:
        result["status"] = "booting"
        result["message"] = "VM is running but SSH not yet accessible (still booting)"
    elif result["process_running"]:
        result["status"] = "starting"
        result["message"] = "VM process running but network not ready"
    else:
        result["status"] = "stopped"
        result["message"] = "No VM found on this port"

    return result
