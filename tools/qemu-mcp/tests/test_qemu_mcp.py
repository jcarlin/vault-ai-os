"""
Tests for QEMU MCP Server

These tests verify the wrapper functions work correctly.
Some tests require QEMU to be installed.
"""

import asyncio
import os
import tempfile
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from qemu_mcp import qemu_img, qemu_system


class TestQemuImgHelpers:
    """Test helper functions in qemu_img module."""

    def test_format_size_bytes(self):
        assert qemu_img._format_size(500) == "500.0 B"

    def test_format_size_kb(self):
        assert qemu_img._format_size(2048) == "2.0 KB"

    def test_format_size_mb(self):
        assert qemu_img._format_size(5 * 1024 * 1024) == "5.0 MB"

    def test_format_size_gb(self):
        assert qemu_img._format_size(100 * 1024 * 1024 * 1024) == "100.0 GB"

    def test_validate_size_absolute(self):
        assert qemu_img._validate_size_string("100G") is True
        assert qemu_img._validate_size_string("50M") is True
        assert qemu_img._validate_size_string("1T") is True

    def test_validate_size_relative(self):
        assert qemu_img._validate_size_string("+10G") is True
        assert qemu_img._validate_size_string("-5G") is True
        assert qemu_img._validate_size_string("+500M") is True

    def test_validate_size_invalid(self):
        assert qemu_img._validate_size_string("invalid") is False
        assert qemu_img._validate_size_string("100") is False  # Missing unit
        assert qemu_img._validate_size_string("") is False


class TestQemuSystemHelpers:
    """Test helper functions in qemu_system module."""

    def test_detect_accelerator_darwin(self):
        with patch("platform.system", return_value="Darwin"):
            assert qemu_system.detect_accelerator() == "hvf"

    def test_detect_accelerator_linux_with_kvm(self):
        with patch("platform.system", return_value="Linux"):
            with patch("os.path.exists", return_value=True):
                with patch("os.access", return_value=True):
                    assert qemu_system.detect_accelerator() == "kvm"

    def test_detect_accelerator_linux_without_kvm(self):
        with patch("platform.system", return_value="Linux"):
            with patch("os.path.exists", return_value=False):
                assert qemu_system.detect_accelerator() == "tcg"

    def test_detect_accelerator_windows(self):
        with patch("platform.system", return_value="Windows"):
            assert qemu_system.detect_accelerator() == "tcg"

    def test_extract_ssh_port(self):
        cmd = "qemu-system-x86_64 -netdev user,id=net0,hostfwd=tcp::2222-:22"
        assert qemu_system._extract_ssh_port(cmd) == 2222

    def test_extract_ssh_port_none(self):
        cmd = "qemu-system-x86_64 -m 4G"
        assert qemu_system._extract_ssh_port(cmd) is None

    def test_is_port_in_use(self):
        # Port 22 is typically SSH and may or may not be in use
        # Port 65432 is unlikely to be in use
        result = qemu_system.is_port_in_use(65432)
        assert isinstance(result, bool)


class TestQemuImgCommands:
    """Test qemu-img command wrappers."""

    @pytest.mark.asyncio
    async def test_image_info_file_not_found(self):
        with pytest.raises(FileNotFoundError):
            await qemu_img.image_info("/nonexistent/path/image.qcow2")

    @pytest.mark.asyncio
    async def test_image_convert_source_not_found(self):
        with pytest.raises(FileNotFoundError):
            await qemu_img.image_convert(
                "/nonexistent/source.qcow2",
                "/tmp/output.raw",
                "raw",
            )

    @pytest.mark.asyncio
    async def test_image_convert_invalid_format(self):
        with tempfile.NamedTemporaryFile(suffix=".qcow2") as tmp:
            with pytest.raises(ValueError, match="Invalid format"):
                await qemu_img.image_convert(
                    tmp.name,
                    "/tmp/output.xyz",
                    "invalid_format",
                )

    @pytest.mark.asyncio
    async def test_create_overlay_base_not_found(self):
        with pytest.raises(FileNotFoundError):
            await qemu_img.create_overlay(
                "/nonexistent/base.qcow2",
                "/tmp/overlay.qcow2",
            )

    @pytest.mark.asyncio
    async def test_image_resize_file_not_found(self):
        with pytest.raises(FileNotFoundError):
            await qemu_img.image_resize("/nonexistent/image.qcow2", "+10G")

    @pytest.mark.asyncio
    async def test_image_resize_invalid_size(self):
        with tempfile.NamedTemporaryFile(suffix=".qcow2") as tmp:
            with pytest.raises(ValueError, match="Invalid size"):
                await qemu_img.image_resize(tmp.name, "invalid")


class TestQemuSystemCommands:
    """Test qemu-system command wrappers."""

    @pytest.mark.asyncio
    async def test_boot_vm_image_not_found(self):
        with pytest.raises(FileNotFoundError):
            await qemu_system.boot_vm("/nonexistent/image.qcow2")

    @pytest.mark.asyncio
    async def test_stop_vm_missing_params(self):
        with pytest.raises(ValueError, match="Must provide"):
            await qemu_system.stop_vm()

    @pytest.mark.asyncio
    async def test_list_vms(self):
        result = await qemu_system.list_vms()
        assert "vms" in result
        assert "count" in result
        assert isinstance(result["vms"], list)

    @pytest.mark.asyncio
    async def test_vm_status_stopped(self):
        # Use a port that's unlikely to have a VM
        result = await qemu_system.vm_status(65433)
        assert result["status"] == "stopped"
        assert result["port_open"] is False


class TestRunCommand:
    """Test the run_command helper."""

    @pytest.mark.asyncio
    async def test_run_command_success(self):
        returncode, stdout, stderr = await qemu_img.run_command(["echo", "hello"])
        assert returncode == 0
        assert "hello" in stdout

    @pytest.mark.asyncio
    async def test_run_command_failure(self):
        returncode, stdout, stderr = await qemu_img.run_command(["false"])
        assert returncode != 0

    @pytest.mark.asyncio
    async def test_run_command_timeout(self):
        with pytest.raises(TimeoutError):
            await qemu_img.run_command(["sleep", "10"], timeout=1)


# Integration tests - only run if QEMU is installed
@pytest.mark.skipif(
    not os.path.exists("/usr/bin/qemu-img")
    and not os.path.exists("/usr/local/bin/qemu-img")
    and not os.path.exists("/opt/homebrew/bin/qemu-img"),
    reason="QEMU not installed",
)
class TestQemuIntegration:
    """Integration tests that require QEMU to be installed."""

    @pytest.mark.asyncio
    async def test_create_and_inspect_image(self):
        """Create a qcow2 image and get its info."""
        with tempfile.TemporaryDirectory() as tmpdir:
            image_path = Path(tmpdir) / "test.qcow2"

            # Create a small test image
            proc = await asyncio.create_subprocess_exec(
                "qemu-img", "create", "-f", "qcow2", str(image_path), "1G",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            await proc.communicate()
            assert proc.returncode == 0

            # Get info
            info = await qemu_img.image_info(str(image_path))
            assert info["format"] == "qcow2"
            assert info["virtual-size"] == 1024 * 1024 * 1024  # 1GB

    @pytest.mark.asyncio
    async def test_create_overlay(self):
        """Create an overlay image."""
        with tempfile.TemporaryDirectory() as tmpdir:
            base_path = Path(tmpdir) / "base.qcow2"
            overlay_path = Path(tmpdir) / "overlay.qcow2"

            # Create base image
            proc = await asyncio.create_subprocess_exec(
                "qemu-img", "create", "-f", "qcow2", str(base_path), "1G",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            await proc.communicate()

            # Create overlay
            result = await qemu_img.create_overlay(str(base_path), str(overlay_path))
            assert result["success"] is True
            assert overlay_path.exists()

            # Verify overlay info
            info = await qemu_img.image_info(str(overlay_path))
            assert info["format"] == "qcow2"
            assert "backing-filename" in info

    @pytest.mark.asyncio
    async def test_image_resize(self):
        """Resize an image."""
        with tempfile.TemporaryDirectory() as tmpdir:
            image_path = Path(tmpdir) / "test.qcow2"

            # Create image
            proc = await asyncio.create_subprocess_exec(
                "qemu-img", "create", "-f", "qcow2", str(image_path), "1G",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            await proc.communicate()

            # Resize
            result = await qemu_img.image_resize(str(image_path), "+500M")
            assert result["success"] is True

            # Verify new size
            info = await qemu_img.image_info(str(image_path))
            expected_size = (1024 + 512) * 1024 * 1024  # 1.5GB
            assert info["virtual-size"] == expected_size
