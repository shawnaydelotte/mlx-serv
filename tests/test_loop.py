"""Tests for main Ralph Loop orchestration."""

import pytest
from unittest.mock import Mock, patch
from pathlib import Path
from ralph_loop.loop import RalphLoop


def test_ralph_loop_initialization(tmp_path):
    """Ralph Loop should initialize with config."""
    loop = RalphLoop(
        task_description="Test task",
        ralph_dir=tmp_path / ".ralph",
        model="7b",
        max_iterations=3
    )

    assert loop.task_description == "Test task"
    assert loop.max_iterations == 3


@patch('ralph_loop.loop.ModelSelector')
@patch('ralph_loop.loop.RalphAPIClient')
@patch('ralph_loop.loop.StateManager')
def test_ralph_loop_selects_model(mock_state, mock_client, mock_selector, tmp_path):
    """Ralph Loop should auto-select model based on task."""
    mock_selector.return_value.select_model.return_value = "3b"

    loop = RalphLoop(
        task_description="format code",
        ralph_dir=tmp_path / ".ralph"
    )

    # Should have selected 3B model
    assert mock_client.call_args[1]["model"] == "3b"


@patch('ralph_loop.loop.PlanPhase')
@patch('ralph_loop.loop.ExecutePhase')
@patch('ralph_loop.loop.ReviewPhase')
@patch('ralph_loop.loop.RalphAPIClient')
@patch('ralph_loop.loop.StateManager')
def test_ralph_loop_runs_single_iteration(
    mock_state, mock_client, mock_review, mock_execute, mock_plan, tmp_path
):
    """Ralph Loop should run plan-execute-review cycle."""
    # Mock state
    mock_state_obj = Mock()
    mock_state_obj.load.return_value = {
        "iteration": 0,
        "phase": "plan",
        "max_iterations": 5
    }
    mock_state.return_value = mock_state_obj

    # Mock phases
    mock_plan_obj = Mock()
    mock_plan_obj.generate_plan.return_value = "# Test Plan\n## Steps\n1. Do something"
    mock_plan_obj.extract_steps.return_value = ["Do something"]
    mock_plan.return_value = mock_plan_obj

    mock_execute_obj = Mock()
    mock_execute_obj.execute_steps.return_value = [{"step": "Do something", "status": "executed", "step_number": 1}]
    mock_execute.return_value = mock_execute_obj

    mock_review_obj = Mock()
    mock_review_obj.review_execution.return_value = {
        "success": True,
        "review_text": "Success!",
        "criteria_met": ["All done"],
        "next_steps": []
    }
    mock_review.return_value = mock_review_obj

    loop = RalphLoop(
        task_description="Test task",
        ralph_dir=tmp_path / ".ralph",
        auto_approve=True
    )

    result = loop.run_iteration()

    assert result["success"] is True
    assert mock_plan_obj.generate_plan.called
    assert mock_execute_obj.execute_steps.called
    assert mock_review_obj.review_execution.called


@patch('ralph_loop.loop.StateManager')
def test_ralph_loop_respects_max_iterations(mock_state, tmp_path):
    """Ralph Loop should stop after max iterations."""
    mock_state_obj = Mock()
    mock_state_obj.load.return_value = {
        "iteration": 5,  # Already at max
        "phase": "plan",
        "max_iterations": 5
    }
    mock_state.return_value = mock_state_obj

    loop = RalphLoop(
        task_description="Test task",
        ralph_dir=tmp_path / ".ralph",
        max_iterations=5
    )

    assert loop.should_continue() is False


def test_ralph_loop_requires_approval_by_default(tmp_path):
    """Ralph Loop should require user approval unless auto_approve=True."""
    loop = RalphLoop(
        task_description="Test task",
        ralph_dir=tmp_path / ".ralph"
    )

    assert loop.auto_approve is False

    loop_auto = RalphLoop(
        task_description="Test task",
        ralph_dir=tmp_path / ".ralph",
        auto_approve=True
    )

    assert loop_auto.auto_approve is True
