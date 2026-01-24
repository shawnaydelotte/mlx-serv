"""Base MCP server with common functionality."""

import logging
import signal
import sys
from pathlib import Path
from typing import Optional

from mcp.server import Server
from mcp.server.stdio import stdio_server


class BaseMCPServer:
    """Base class for MCP servers with common setup."""

    def __init__(self, name: str, log_file: Optional[Path] = None):
        self.name = name
        self.server = Server(name)
        self.running = False

        # Set up logging
        if log_file:
            log_file.parent.mkdir(parents=True, exist_ok=True)
            logging.basicConfig(
                filename=str(log_file),
                level=logging.INFO,
                format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
        else:
            logging.basicConfig(
                level=logging.INFO,
                format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )

        self.logger = logging.getLogger(name)

        # Handle graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully."""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.running = False
        sys.exit(0)

    async def run(self):
        """Run the MCP server."""
        self.running = True
        self.logger.info(f"Starting {self.name} MCP server...")

        async with stdio_server() as (read_stream, write_stream):
            await self.server.run(
                read_stream,
                write_stream,
                self.server.create_initialization_options()
            )
