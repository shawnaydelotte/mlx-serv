"""Tests for Execute phase."""

import pytest
from unittest.mock import Mock
from ralph_loop.phases.execute import ExecutePhase


def test_execute_phase_initialization():
    """Execute phase should initialize with API client."""
    mock_client = Mock()
    phase = ExecutePhase(mock_client)

    assert phase.client == mock_client


def test_execute_phase_runs_steps():
    """Execute phase should process each step."""
    mock_client = Mock()
    phase = ExecutePhase(mock_client)

    steps = [
        "Read authentication.py",
        "Write test for login bug",
        "Run the test to verify it fails"
    ]

    results = phase.execute_steps(steps)

    assert len(results) == 3
    assert all("step" in r for r in results)
    assert all("status" in r for r in results)


def test_execute_phase_simulation_mode():
    """Execute phase should support simulation without actual changes."""
    mock_client = Mock()
    phase = ExecutePhase(mock_client, simulation=True)

    steps = ["Modify config.py", "Run tests"]
    results = phase.execute_steps(steps)

    assert len(results) == 2
    assert all(r["status"] == "simulated" for r in results)
