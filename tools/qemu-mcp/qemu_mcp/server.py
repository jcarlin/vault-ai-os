"""
QEMU MCP Server

An MCP server that wraps QEMU commands for disk image management
and VM operations. Enables Claude Code to manage test VMs and
automate bare metal deployment workflows.
"""

import asyncio
import json
import logging
from typing import Any

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import TextContent, Tool

from . import qemu_img, qemu_system

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("qemu-mcp")

# Create MCP server instance
server = Server("qemu-mcp")


# Tool definitions
TOOLS = [
    # Image operations
    Tool(
        name="qemu_image_info",
        description="Get detailed information about a disk image including format, virtual size, actual size, and backing file info.",
        inputSchema={
            "type": "object",
            "properties": {
                "image_path": {
                    "type": "string",
                    "description": "Path to the disk image file",
                }
            },
            "required": ["image_path"],
        },
    ),
    Tool(
        name="qemu_image_convert",
        description="Convert a disk image between formats (raw, qcow2, vmdk, vdi, vhdx). Useful for preparing images for different hypervisors.",
        inputSchema={
            "type": "object",
            "properties": {
                "input_path": {
                    "type": "string",
                    "description": "Path to the source image",
                },
                "output_path": {
                    "type": "string",
                    "description": "Path for the output image",
                },
                "output_format": {
                    "type": "string",
                    "description": "Target format: raw, qcow2, vmdk, vdi, vhdx",
                    "enum": ["raw", "qcow2", "vmdk", "vdi", "vhdx"],
                },
                "input_format": {
                    "type": "string",
                    "description": "Source format (auto-detected if not specified)",
                },
                "compress": {
                    "type": "boolean",
                    "description": "Enable compression (only for qcow2 output)",
                    "default": False,
                },
            },
            "required": ["input_path", "output_path", "output_format"],
        },
    ),
    Tool(
        name="qemu_create_overlay",
        description="Create a copy-on-write overlay image backed by a base image. Changes go to the overlay without modifying the original - perfect for testing.",
        inputSchema={
            "type": "object",
            "properties": {
                "base_image": {
                    "type": "string",
                    "description": "Path to the backing image (will not be modified)",
                },
                "overlay_path": {
                    "type": "string",
                    "description": "Path for the new overlay image",
                },
            },
            "required": ["base_image", "overlay_path"],
        },
    ),
    Tool(
        name="qemu_image_resize",
        description="Resize a disk image. Use +/- prefix for relative sizing.",
        inputSchema={
            "type": "object",
            "properties": {
                "image_path": {
                    "type": "string",
                    "description": "Path to the disk image",
                },
                "size": {
                    "type": "string",
                    "description": "New size (e.g., '100G', '+10G', '-5G')",
                },
            },
            "required": ["image_path", "size"],
        },
    ),
    # VM operations
    Tool(
        name="qemu_boot_vm",
        description="Boot a disk image in QEMU for testing. Automatically detects and uses the best available accelerator (KVM/HVF/TCG).",
        inputSchema={
            "type": "object",
            "properties": {
                "image_path": {
                    "type": "string",
                    "description": "Path to the disk image to boot",
                },
                "memory": {
                    "type": "string",
                    "description": "RAM allocation (e.g., '4G', '8192M')",
                    "default": "4G",
                },
                "cpus": {
                    "type": "integer",
                    "description": "Number of CPU cores",
                    "default": 2,
                },
                "ssh_port": {
                    "type": "integer",
                    "description": "Host port to forward to guest SSH (port 22)",
                    "default": 2222,
                },
                "background": {
                    "type": "boolean",
                    "description": "Run in background (true) or return command for manual execution (false)",
                    "default": True,
                },
            },
            "required": ["image_path"],
        },
    ),
    Tool(
        name="qemu_list_vms",
        description="List all running QEMU virtual machines with their PIDs and SSH ports.",
        inputSchema={
            "type": "object",
            "properties": {},
        },
    ),
    Tool(
        name="qemu_stop_vm",
        description="Stop a running QEMU VM by PID or SSH port.",
        inputSchema={
            "type": "object",
            "properties": {
                "pid": {
                    "type": "integer",
                    "description": "Process ID of the VM to stop",
                },
                "ssh_port": {
                    "type": "integer",
                    "description": "SSH port of the VM to stop (alternative to pid)",
                },
            },
        },
    ),
    Tool(
        name="qemu_vm_status",
        description="Check if a VM is running and whether SSH is accessible.",
        inputSchema={
            "type": "object",
            "properties": {
                "ssh_port": {
                    "type": "integer",
                    "description": "SSH port to check",
                },
            },
            "required": ["ssh_port"],
        },
    ),
]


@server.list_tools()
async def list_tools() -> list[Tool]:
    """Return the list of available tools."""
    return TOOLS


@server.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> list[TextContent]:
    """Handle tool calls."""
    logger.info(f"Tool call: {name} with args: {arguments}")

    try:
        result = await _dispatch_tool(name, arguments)
        return [TextContent(type="text", text=json.dumps(result, indent=2))]
    except Exception as e:
        logger.error(f"Tool error: {e}")
        error_result = {
            "error": True,
            "error_type": type(e).__name__,
            "message": str(e),
        }
        return [TextContent(type="text", text=json.dumps(error_result, indent=2))]


async def _dispatch_tool(name: str, arguments: dict[str, Any]) -> dict:
    """Dispatch tool call to appropriate handler."""

    # Image operations
    if name == "qemu_image_info":
        return await qemu_img.image_info(arguments["image_path"])

    elif name == "qemu_image_convert":
        return await qemu_img.image_convert(
            input_path=arguments["input_path"],
            output_path=arguments["output_path"],
            output_format=arguments["output_format"],
            input_format=arguments.get("input_format"),
            compress=arguments.get("compress", False),
        )

    elif name == "qemu_create_overlay":
        return await qemu_img.create_overlay(
            base_image=arguments["base_image"],
            overlay_path=arguments["overlay_path"],
        )

    elif name == "qemu_image_resize":
        return await qemu_img.image_resize(
            image_path=arguments["image_path"],
            size=arguments["size"],
        )

    # VM operations
    elif name == "qemu_boot_vm":
        return await qemu_system.boot_vm(
            image_path=arguments["image_path"],
            memory=arguments.get("memory", "4G"),
            cpus=arguments.get("cpus", 2),
            ssh_port=arguments.get("ssh_port", 2222),
            background=arguments.get("background", True),
        )

    elif name == "qemu_list_vms":
        return await qemu_system.list_vms()

    elif name == "qemu_stop_vm":
        return await qemu_system.stop_vm(
            pid=arguments.get("pid"),
            ssh_port=arguments.get("ssh_port"),
        )

    elif name == "qemu_vm_status":
        return await qemu_system.vm_status(
            ssh_port=arguments["ssh_port"],
        )

    else:
        raise ValueError(f"Unknown tool: {name}")


async def run_server():
    """Run the MCP server."""
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options(),
        )


def main():
    """Entry point for the server."""
    asyncio.run(run_server())


if __name__ == "__main__":
    main()
