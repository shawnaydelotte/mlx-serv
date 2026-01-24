"""Tests for Plan phase."""

import pytest
from unittest.mock import Mock, patch
from pathlib import Path
from ralph_loop.phases.plan import PlanPhase


def test_plan_phase_initialization():
    """Plan phase should initialize with API client."""
    mock_client = Mock()
    phase = PlanPhase(mock_client)

    assert phase.client == mock_client


@patch('ralph_loop.phases.plan.RalphAPIClient')
def test_plan_phase_generates_plan(mock_client_class):
    """Plan phase should generate structured plan."""
    mock_client = Mock()
    mock_client_class.return_value = mock_client

    # Mock LLM response
    mock_client.send_message.return_value = """
# Implementation Plan

## Steps

1. Read the current authentication code
2. Identify the bug causing login failures
3. Write a test that reproduces the bug
4. Fix the bug
5. Verify the test passes

## Success Criteria

- All existing tests pass
- New test reproduces and validates fix
- No regressions in related features
"""

    phase = PlanPhase(mock_client)
    plan = phase.generate_plan("Fix authentication bug causing login failures")

    assert "Read the current authentication code" in plan
    assert "Success Criteria" in plan
    assert mock_client.send_message.called


@patch('ralph_loop.phases.plan.RalphAPIClient')
def test_plan_phase_saves_to_file(mock_client_class, tmp_path):
    """Plan phase should save plan to .ralph/current-plan.md"""
    mock_client = Mock()
    mock_client_class.return_value = mock_client

    mock_client.send_message.return_value = "# Test Plan\n\nStep 1: Do something"

    ralph_dir = tmp_path / ".ralph"
    ralph_dir.mkdir()

    phase = PlanPhase(mock_client)
    plan = phase.generate_plan("Test task", save_to=ralph_dir / "current-plan.md")

    plan_file = ralph_dir / "current-plan.md"
    assert plan_file.exists()

    content = plan_file.read_text()
    assert "# Test Plan" in content


def test_plan_phase_extracts_steps():
    """Plan phase should extract numbered steps from plan."""
    mock_client = Mock()
    phase = PlanPhase(mock_client)

    plan = """
# Plan

## Steps

1. First step
2. Second step
3. Third step

## Success Criteria

- Tests pass
"""

    steps = phase.extract_steps(plan)

    assert len(steps) == 3
    assert steps[0] == "First step"
    assert steps[1] == "Second step"
    assert steps[2] == "Third step"
