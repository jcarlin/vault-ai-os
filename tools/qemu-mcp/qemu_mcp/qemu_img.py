"""
Wrapper functions for qemu-img commands.

Provides disk image operations: info, convert, create overlay, resize.
"""

import asyncio
import json
import os
import shutil
from pathlib import Path
from typing import Optional


async def run_command(cmd: list[str], timeout: int = 300) -> tuple[int, str, str]:
    """Run a command asynchronously and return (returncode, stdout, stderr)."""
    process = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(
            process.communicate(), timeout=timeout
        )
        return process.returncode or 0, stdout.decode(), stderr.decode()
    except asyncio.TimeoutError:
        process.kill()
        await process.wait()
        raise TimeoutError(f"Command timed out after {timeout}s: {' '.join(cmd)}")


def get_qemu_img_path() -> str:
    """Find qemu-img executable."""
    path = shutil.which("qemu-img")
    if not path:
        raise FileNotFoundError(
            "qemu-img not found. Install QEMU: brew install qemu (macOS) or apt install qemu-utils (Linux)"
        )
    return path


async def image_info(image_path: str) -> dict:
    """
    Get detailed information about a disk image.

    Args:
        image_path: Path to the disk image

    Returns:
        Dictionary with image info (format, virtual-size, actual-size, etc.)
    """
    path = Path(image_path).expanduser().resolve()
    if not path.exists():
        raise FileNotFoundError(f"Image not found: {image_path}")

    qemu_img = get_qemu_img_path()
    returncode, stdout, stderr = await run_command([
        qemu_img, "info", "--output=json", str(path)
    ])

    if returncode != 0:
        raise RuntimeError(f"qemu-img info failed: {stderr}")

    info = json.loads(stdout)

    # Add human-readable sizes
    if "virtual-size" in info:
        info["virtual-size-human"] = _format_size(info["virtual-size"])
    if "actual-size" in info:
        info["actual-size-human"] = _format_size(info["actual-size"])

    return info


async def image_convert(
    input_path: str,
    output_path: str,
    output_format: str,
    input_format: Optional[str] = None,
    compress: bool = False,
) -> dict:
    """
    Convert a disk image to a different format.

    Args:
        input_path: Path to source image
        output_path: Path for output image
        output_format: Target format (raw, qcow2, vmdk, vdi, vhdx)
        input_format: Source format (auto-detected if not specified)
        compress: Enable compression (for qcow2)

    Returns:
        Dictionary with conversion results
    """
    src = Path(input_path).expanduser().resolve()
    dst = Path(output_path).expanduser().resolve()

    if not src.exists():
        raise FileNotFoundError(f"Source image not found: {input_path}")

    if dst.exists():
        raise FileExistsError(f"Output path already exists: {output_path}")

    # Ensure output directory exists
    dst.parent.mkdir(parents=True, exist_ok=True)

    valid_formats = {"raw", "qcow2", "vmdk", "vdi", "vhdx", "vpc"}
    if output_format not in valid_formats:
        raise ValueError(f"Invalid format '{output_format}'. Valid: {valid_formats}")

    qemu_img = get_qemu_img_path()
    cmd = [qemu_img, "convert"]

    if input_format:
        cmd.extend(["-f", input_format])

    cmd.extend(["-O", output_format])

    if compress and output_format == "qcow2":
        cmd.append("-c")

    cmd.extend([str(src), str(dst)])

    returncode, stdout, stderr = await run_command(cmd, timeout=3600)  # 1 hour timeout for large images

    if returncode != 0:
        # Clean up partial output
        if dst.exists():
            dst.unlink()
        raise RuntimeError(f"qemu-img convert failed: {stderr}")

    # Get info about the new image
    new_info = await image_info(str(dst))

    return {
        "success": True,
        "input_path": str(src),
        "output_path": str(dst),
        "output_format": output_format,
        "output_size": new_info.get("actual-size-human", "unknown"),
        "virtual_size": new_info.get("virtual-size-human", "unknown"),
    }


async def create_overlay(base_image: str, overlay_path: str) -> dict:
    """
    Create a copy-on-write overlay image backed by a base image.

    This allows testing/modifications without changing the original.

    Args:
        base_image: Path to the backing image (will not be modified)
        overlay_path: Path for the new overlay image

    Returns:
        Dictionary with overlay creation results
    """
    base = Path(base_image).expanduser().resolve()
    overlay = Path(overlay_path).expanduser().resolve()

    if not base.exists():
        raise FileNotFoundError(f"Base image not found: {base_image}")

    if overlay.exists():
        raise FileExistsError(f"Overlay path already exists: {overlay_path}")

    # Ensure output directory exists
    overlay.parent.mkdir(parents=True, exist_ok=True)

    # Get base image info
    base_info = await image_info(str(base))
    base_format = base_info.get("format", "raw")

    qemu_img = get_qemu_img_path()
    cmd = [
        qemu_img, "create",
        "-f", "qcow2",
        "-F", base_format,
        "-b", str(base),
        str(overlay),
    ]

    returncode, stdout, stderr = await run_command(cmd)

    if returncode != 0:
        raise RuntimeError(f"qemu-img create overlay failed: {stderr}")

    return {
        "success": True,
        "overlay_path": str(overlay),
        "backing_file": str(base),
        "backing_format": base_format,
        "note": "Changes to overlay will not affect the base image",
    }


async def image_resize(image_path: str, size: str) -> dict:
    """
    Resize a disk image.

    Args:
        image_path: Path to the disk image
        size: New size (e.g., "100G", "+10G", "-5G")

    Returns:
        Dictionary with resize results
    """
    path = Path(image_path).expanduser().resolve()

    if not path.exists():
        raise FileNotFoundError(f"Image not found: {image_path}")

    # Validate size format
    if not _validate_size_string(size):
        raise ValueError(
            f"Invalid size format: {size}. Use formats like '100G', '+10G', '-5G'"
        )

    # Get current info
    before_info = await image_info(str(path))

    qemu_img = get_qemu_img_path()
    cmd = [qemu_img, "resize", str(path), size]

    returncode, stdout, stderr = await run_command(cmd)

    if returncode != 0:
        raise RuntimeError(f"qemu-img resize failed: {stderr}")

    # Get new info
    after_info = await image_info(str(path))

    return {
        "success": True,
        "image_path": str(path),
        "size_before": before_info.get("virtual-size-human", "unknown"),
        "size_after": after_info.get("virtual-size-human", "unknown"),
    }


def _format_size(size_bytes: int) -> str:
    """Format bytes as human-readable string."""
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if abs(size_bytes) < 1024.0:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.1f} PB"


def _validate_size_string(size: str) -> bool:
    """Validate a size string like '100G', '+10G', '-5G'."""
    import re
    pattern = r'^[+-]?\d+(\.\d+)?[KMGTkmgt]?$'
    return bool(re.match(pattern, size))
