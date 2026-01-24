"""Tests for automatic model selection."""

import pytest
from ralph_loop.model_selector import ModelSelector


def test_model_selector_defaults_to_7b():
    """Unknown tasks should default to 7B (quality)."""
    selector = ModelSelector()

    assert selector.select_model("write some code") == "7b"
    assert selector.select_model("help me with this") == "7b"


def test_model_selector_uses_3b_for_simple_tasks():
    """Simple keywords should select 3B (fast)."""
    selector = ModelSelector()

    assert selector.select_model("format this code") == "3b"
    assert selector.select_model("add comments to functions") == "3b"
    assert selector.select_model("generate unit tests") == "3b"
    assert selector.select_model("fix typo in variable name") == "3b"


def test_model_selector_uses_7b_for_complex_tasks():
    """Complex keywords should select 7B (quality)."""
    selector = ModelSelector()

    assert selector.select_model("refactor the authentication system") == "7b"
    assert selector.select_model("debug this complex race condition") == "7b"
    assert selector.select_model("optimize the database queries") == "7b"
    assert selector.select_model("design a new API architecture") == "7b"


def test_model_selector_respects_manual_override():
    """Manual model selection should override automatic selection."""
    selector = ModelSelector(force_model="3b")

    # Even complex task should use 3B when forced
    assert selector.select_model("refactor architecture") == "3b"

    selector = ModelSelector(force_model="7b")

    # Even simple task should use 7B when forced
    assert selector.select_model("format code") == "7b"


def test_model_selector_case_insensitive():
    """Keyword matching should be case-insensitive."""
    selector = ModelSelector()

    assert selector.select_model("REFACTOR the code") == "7b"
    assert selector.select_model("Format The Code") == "3b"
