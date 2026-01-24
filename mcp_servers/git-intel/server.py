"""Git Intelligence MCP Server for repository analysis."""

import asyncio
from pathlib import Path
import sys
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).parent.parent))

from base_server import BaseMCPServer
import git
import networkx as nx


class GitIntelServer(BaseMCPServer):
    """MCP server providing git repository intelligence."""

    def __init__(self, repo_path: str = "."):
        log_file = Path.home() / ".ralph" / "mcp-git-intel.log"
        super().__init__("git-intel", log_file)

        self.repo_path = Path(repo_path)
        self.repo = None
        self.cochange_graph = None

        # Initialize repository
        try:
            self.repo = git.Repo(self.repo_path)
            self.logger.info(f"Initialized repo at {self.repo_path}")
        except git.InvalidGitRepositoryError:
            self.logger.error(f"Not a git repository: {self.repo_path}")

        # Register tools
        self.register_tools()

    def build_cochange_graph(self, limit: int = 100):
        """Build graph of files that change together."""
        if not self.repo:
            return None

        # Cap limit to prevent memory issues
        limit = min(limit, 1000)

        graph = nx.Graph()
        commits = list(self.repo.iter_commits(max_count=limit))

        for commit in commits:
            if not commit.parents:
                continue

            # Get files changed in this commit
            changed_files = []
            for diff in commit.parents[0].diff(commit):
                if diff.a_path:
                    changed_files.append(diff.a_path)
                if diff.b_path and diff.b_path != diff.a_path:
                    changed_files.append(diff.b_path)

            # Add edges between co-changed files
            for i, file1 in enumerate(changed_files):
                for file2 in changed_files[i+1:]:
                    if graph.has_edge(file1, file2):
                        graph[file1][file2]['weight'] += 1
                    else:
                        graph.add_edge(file1, file2, weight=1)

        return graph

    def register_tools(self):
        """Register git intelligence tools."""

        @self.server.call_tool()
        async def analyze_changes(since_commit: str = "HEAD~10") -> dict:
            """Analyze changes since a specific commit.

            Args:
                since_commit: Git ref to compare from (default: HEAD~10)

            Returns:
                Dict with files_changed, insertions, deletions, summary
            """
            if not self.repo:
                raise Exception("Not a git repository")

            try:
                commits = list(self.repo.iter_commits(f"{since_commit}..HEAD"))

                stats = {
                    "num_commits": len(commits),
                    "files_changed": set(),
                    "insertions": 0,
                    "deletions": 0,
                    "authors": set()
                }

                for commit in commits:
                    stats["authors"].add(commit.author.name)
                    for file in commit.stats.files:
                        stats["files_changed"].add(file)
                        stats["insertions"] += commit.stats.files[file]["insertions"]
                        stats["deletions"] += commit.stats.files[file]["deletions"]

                return {
                    "commits": stats["num_commits"],
                    "files": sorted(list(stats["files_changed"])),
                    "insertions": stats["insertions"],
                    "deletions": stats["deletions"],
                    "authors": sorted(list(stats["authors"])),
                    "summary": f"{stats['num_commits']} commits changed {len(stats['files_changed'])} files (+{stats['insertions']}/-{stats['deletions']})"
                }

            except Exception as e:
                self.logger.error(f"analyze_changes error: {e}")
                raise Exception(f"Git analysis error: {str(e)}")

        @self.server.call_tool()
        async def find_related_files(file_path: str, limit: int = 5) -> list[str]:
            """Find files that often change together with the given file.

            Args:
                file_path: Path to file relative to repo root
                limit: Maximum number of related files to return

            Returns:
                List of related file paths sorted by relationship strength
            """
            if not self.repo:
                raise Exception("Not a git repository")

            # Validate limit
            limit = max(1, min(limit, 50))  # Between 1 and 50

            # Build co-change graph if needed
            if not self.cochange_graph:
                self.logger.info("Building co-change graph...")
                self.cochange_graph = await asyncio.to_thread(self.build_cochange_graph)

            if not self.cochange_graph or file_path not in self.cochange_graph:
                return []

            # Get neighbors sorted by edge weight
            neighbors = []
            for neighbor in self.cochange_graph.neighbors(file_path):
                weight = self.cochange_graph[file_path][neighbor]['weight']
                neighbors.append((neighbor, weight))

            neighbors.sort(key=lambda x: x[1], reverse=True)
            return [f for f, w in neighbors[:limit]]

        @self.server.call_tool()
        async def explain_commit(sha: str) -> dict:
            """Get detailed information about a commit.

            Args:
                sha: Commit SHA (full or short)

            Returns:
                Dict with author, date, message, files_changed, stats
            """
            if not self.repo:
                raise Exception("Not a git repository")

            try:
                commit = self.repo.commit(sha)

                files_changed = []
                if commit.parents:
                    for file_path, file_stats in commit.stats.files.items():
                        # Find the diff to get change_type
                        change_type = "M"  # Default to modified
                        for diff in commit.parents[0].diff(commit):
                            if diff.a_path == file_path or diff.b_path == file_path:
                                change_type = diff.change_type
                                break

                        files_changed.append({
                            "path": file_path,
                            "change_type": change_type,
                            "insertions": file_stats["insertions"],
                            "deletions": file_stats["deletions"]
                        })

                return {
                    "sha": commit.hexsha,
                    "author": commit.author.name,
                    "email": commit.author.email,
                    "date": commit.committed_datetime.isoformat(),
                    "message": commit.message.strip(),
                    "files_changed": files_changed,
                    "total_insertions": sum(f["insertions"] for f in files_changed),
                    "total_deletions": sum(f["deletions"] for f in files_changed)
                }

            except Exception as e:
                self.logger.error(f"explain_commit error: {e}")
                raise Exception(f"Commit analysis error: {str(e)}")

        # Register tools with server
        self.server.list_tools.extend([
            {
                "name": "analyze_changes",
                "description": "Analyze git changes since a specific commit",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "since_commit": {
                            "type": "string",
                            "description": "Git ref to compare from",
                            "default": "HEAD~10"
                        }
                    }
                }
            },
            {
                "name": "find_related_files",
                "description": "Find files that often change together with a given file",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "file_path": {
                            "type": "string",
                            "description": "Path to file"
                        },
                        "limit": {
                            "type": "integer",
                            "description": "Max results",
                            "default": 5
                        }
                    },
                    "required": ["file_path"]
                }
            },
            {
                "name": "explain_commit",
                "description": "Get detailed information about a specific commit",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "sha": {
                            "type": "string",
                            "description": "Commit SHA"
                        }
                    },
                    "required": ["sha"]
                }
            }
        ])


async def main():
    """Run the git intelligence MCP server."""
    server = GitIntelServer()
    await server.run()


if __name__ == "__main__":
    asyncio.run(main())
