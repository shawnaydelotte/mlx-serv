"""Automatic model selection based on task complexity."""

from typing import Optional


class ModelSelector:
    """Selects appropriate model (3B fast vs 7B quality) based on task."""

    # Keywords that indicate simple/fast tasks (use 3B)
    FAST_KEYWORDS = [
        "format", "comment", "comments", "test", "tests",
        "typo", "fix typo", "rename", "documentation",
        "docstring", "lint"
    ]

    # Keywords that indicate complex tasks (use 7B)
    QUALITY_KEYWORDS = [
        "refactor", "architecture", "debug", "complex",
        "optimize", "design", "algorithm", "performance",
        "security", "race condition"
    ]

    def __init__(self, force_model: Optional[str] = None):
        """
        Initialize model selector.

        Args:
            force_model: Override automatic selection ("3b" or "7b")
        """
        self.force_model = force_model

    def select_model(self, task_description: str) -> str:
        """
        Select appropriate model based on task description.

        Args:
            task_description: Description of the coding task

        Returns:
            "3b" for fast model or "7b" for quality model
        """
        # Manual override takes precedence
        if self.force_model:
            return self.force_model

        # Normalize to lowercase for matching
        task_lower = task_description.lower()

        # Check for quality keywords first (more important)
        for keyword in self.QUALITY_KEYWORDS:
            if keyword in task_lower:
                return "7b"

        # Check for fast keywords
        for keyword in self.FAST_KEYWORDS:
            if keyword in task_lower:
                return "3b"

        # Default to quality model when uncertain
        return "7b"
