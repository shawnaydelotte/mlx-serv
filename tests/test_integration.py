"""Integration tests for Ralph Loop."""

import pytest
from pathlib import Path
from unittest.mock import Mock, patch
from ralph_loop.loop import RalphLoop


@patch('ralph_loop.api_client.Anthropic')
def test_full_loop_simulation(mock_anthropic, tmp_path):
    """Full loop should run plan-execute-review cycle."""
    # Mock Anthropic client
    mock_client = Mock()
    mock_anthropic.return_value = mock_client

    # Mock responses for different phases
    responses = [
        # Plan phase
        Mock(content=[Mock(text="""
# Implementation Plan

## Steps

1. Read config.py
2. Update timeout value
3. Run tests to verify

## Success Criteria

- Tests pass
- Config updated
""")]),
        # Review phase
        Mock(content=[Mock(text="""
# Review Results

## Success: Yes

All criteria met!
""")])
    ]

    mock_client.messages.create.side_effect = responses

    # Run loop
    ralph_dir = tmp_path / ".ralph"
    loop = RalphLoop(
        task_description="Update timeout in config",
        ralph_dir=ralph_dir,
        auto_approve=True,
        max_iterations=1
    )

    results = loop.run()

    # Verify results
    assert results["final_success"] is True
    assert results["total_iterations"] == 1

    # Verify state was saved
    assert (ralph_dir / "state.json").exists()
    assert (ralph_dir / "current-plan.md").exists()


@patch('ralph_loop.api_client.Anthropic')
def test_loop_with_multiple_iterations(mock_anthropic, tmp_path):
    """Loop should iterate until success or max iterations."""
    mock_client = Mock()
    mock_anthropic.return_value = mock_client

    # First iteration fails, second succeeds
    responses = [
        # Iteration 1 - Plan
        Mock(content=[Mock(text="# Plan\n## Steps\n1. Do something")]),
        # Iteration 1 - Review (failure)
        Mock(content=[Mock(text="# Review\n## Success: No")]),
        # Iteration 2 - Plan (refined)
        Mock(content=[Mock(text="# Refined Plan\n## Steps\n1. Do it better")]),
        # Iteration 2 - Review (success)
        Mock(content=[Mock(text="# Review\n## Success: Yes")])
    ]

    mock_client.messages.create.side_effect = responses

    ralph_dir = tmp_path / ".ralph"
    loop = RalphLoop(
        task_description="Test task",
        ralph_dir=ralph_dir,
        auto_approve=True,
        max_iterations=5
    )

    results = loop.run()

    assert results["final_success"] is True
    assert results["total_iterations"] == 2


@patch('ralph_loop.api_client.Anthropic')
def test_loop_stops_at_max_iterations(mock_anthropic, tmp_path):
    """Loop should stop after max iterations even if not successful."""
    mock_client = Mock()
    mock_anthropic.return_value = mock_client

    # All iterations fail
    responses = []
    for i in range(6):  # Plan + Review for 3 iterations
        responses.append(Mock(content=[Mock(text="# Plan\n## Steps\n1. Try again")]))
        responses.append(Mock(content=[Mock(text="# Review\n## Success: No")]))

    mock_client.messages.create.side_effect = responses

    ralph_dir = tmp_path / ".ralph"
    loop = RalphLoop(
        task_description="Impossible task",
        ralph_dir=ralph_dir,
        auto_approve=True,
        max_iterations=3
    )

    results = loop.run()

    assert results["final_success"] is False
    assert results["total_iterations"] == 3
