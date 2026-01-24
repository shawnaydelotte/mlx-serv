"""Web Search MCP Server using DuckDuckGo."""

import asyncio
from pathlib import Path
import sys
import time

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from base_server import BaseMCPServer
from duckduckgo_search import DDGS


class WebSearchServer(BaseMCPServer):
    """MCP server providing web search capabilities."""

    def __init__(self):
        log_file = Path.home() / ".ralph" / "mcp-web-search.log"
        super().__init__("web-search", log_file)

        # Rate limiting
        self.last_search_time = 0
        self.min_interval = 6  # seconds (10 requests/minute max)
        self._rate_limit_lock = asyncio.Lock()

        # Register search tool
        self.register_search_tool()

    def _perform_search(self, query: str, max_results: int) -> list[dict]:
        """Perform synchronous DuckDuckGo search."""
        with DDGS() as ddgs:
            results = []
            for result in ddgs.text(query, max_results=max_results):
                results.append({
                    "title": result.get("title", ""),
                    "url": result.get("href", ""),
                    "snippet": result.get("body", "")
                })
            return results

    def register_search_tool(self):
        """Register the search tool with MCP."""

        @self.server.call_tool()
        async def search(query: str, max_results: int = 5) -> list[dict]:
            """Search DuckDuckGo and return results.

            Args:
                query: Search query string
                max_results: Maximum number of results (default: 5, max: 10)

            Returns:
                List of dicts with title, url, snippet
            """
            # Rate limiting with lock
            async with self._rate_limit_lock:
                now = time.time()
                elapsed = now - self.last_search_time
                if elapsed < self.min_interval:
                    wait_time = self.min_interval - elapsed
                    self.logger.info(f"Rate limiting: waiting {wait_time:.1f}s")
                    await asyncio.sleep(wait_time)

                self.last_search_time = time.time()

            # Limit max_results
            max_results = min(max_results, 10)

            self.logger.info(f"Searching: {query} (max_results={max_results})")

            try:
                results = await asyncio.to_thread(self._perform_search, query, max_results)
                self.logger.info(f"Found {len(results)} results")
                return results

            except Exception as e:
                self.logger.error(f"Search failed: {e}")
                raise Exception(f"Search error: {str(e)}")

        # Register with server
        self.server.list_tools.append({
            "name": "search",
            "description": "Search the web using DuckDuckGo. Returns titles, URLs, and snippets.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Search query"
                    },
                    "max_results": {
                        "type": "integer",
                        "description": "Maximum results to return (1-10)",
                        "default": 5
                    }
                },
                "required": ["query"]
            }
        })


async def main():
    """Run the web search MCP server."""
    server = WebSearchServer()
    await server.run()


if __name__ == "__main__":
    asyncio.run(main())
