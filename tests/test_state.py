"""Tests for Ralph Loop state management."""

import json
from pathlib import Path
import pytest
from ralph_loop.state import StateManager


def test_state_manager_creates_directory(tmp_path):
    """State manager should create .ralph directory if it doesn't exist."""
    ralph_dir = tmp_path / ".ralph"
    assert not ralph_dir.exists()

    StateManager(ralph_dir)

    assert ralph_dir.exists()
    assert ralph_dir.is_dir()


def test_state_manager_initializes_empty_state(tmp_path):
    """New state manager should have empty initial state."""
    ralph_dir = tmp_path / ".ralph"
    sm = StateManager(ralph_dir)

    state = sm.load()

    assert state["iteration"] == 0
    assert state["phase"] == "plan"
    assert state["plan"] is None
    assert state["results"] == []
    assert state["max_iterations"] == 5


def test_state_manager_saves_and_loads(tmp_path):
    """State should persist to disk and reload correctly."""
    ralph_dir = tmp_path / ".ralph"
    sm = StateManager(ralph_dir)

    # Save state
    sm.save({
        "iteration": 2,
        "phase": "execute",
        "plan": "# Test plan",
        "results": [{"iteration": 1, "success": True}],
        "max_iterations": 5
    })

    # Create new state manager (simulating restart)
    sm2 = StateManager(ralph_dir)
    state = sm2.load()

    assert state["iteration"] == 2
    assert state["phase"] == "execute"
    assert state["plan"] == "# Test plan"
    assert len(state["results"]) == 1


def test_state_manager_increments_iteration(tmp_path):
    """State manager should increment iteration count."""
    ralph_dir = tmp_path / ".ralph"
    sm = StateManager(ralph_dir)

    sm.increment_iteration()
    state = sm.load()
    assert state["iteration"] == 1

    sm.increment_iteration()
    state = sm.load()
    assert state["iteration"] == 2


def test_state_manager_updates_phase(tmp_path):
    """State manager should update phase."""
    ralph_dir = tmp_path / ".ralph"
    sm = StateManager(ralph_dir)

    sm.set_phase("execute")
    state = sm.load()
    assert state["phase"] == "execute"

    sm.set_phase("review")
    state = sm.load()
    assert state["phase"] == "review"


def test_state_manager_adds_result(tmp_path):
    """State manager should append iteration results."""
    ralph_dir = tmp_path / ".ralph"
    sm = StateManager(ralph_dir)

    sm.add_result({"iteration": 1, "success": True, "tests_passed": 5})
    sm.add_result({"iteration": 2, "success": False, "error": "Syntax error"})

    state = sm.load()
    assert len(state["results"]) == 2
    assert state["results"][0]["success"] is True
    assert state["results"][1]["success"] is False


def test_state_manager_resets(tmp_path):
    """State manager should reset to initial state."""
    ralph_dir = tmp_path / ".ralph"
    sm = StateManager(ralph_dir)

    # Populate state
    sm.increment_iteration()
    sm.set_phase("review")
    sm.add_result({"iteration": 1, "success": True})

    # Reset
    sm.reset()
    state = sm.load()

    assert state["iteration"] == 0
    assert state["phase"] == "plan"
    assert state["results"] == []
