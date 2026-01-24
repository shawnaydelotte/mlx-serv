"""Tests for CLI interface."""

import pytest
from unittest.mock import Mock, patch
from pathlib import Path
from ralph_loop.cli import main, parse_args


def test_parse_args_basic():
    """CLI should parse basic task description."""
    args = parse_args(["Fix authentication bug"])

    assert args.task == "Fix authentication bug"
    assert args.model is None
    assert args.max_iterations == 5
    assert args.auto is False


def test_parse_args_with_model():
    """CLI should parse --model flag."""
    args = parse_args(["--model", "3b", "Format code"])

    assert args.task == "Format code"
    assert args.model == "3b"


def test_parse_args_with_max_iterations():
    """CLI should parse --max-iterations flag."""
    args = parse_args(["--max-iterations", "10", "Refactor API"])

    assert args.task == "Refactor API"
    assert args.max_iterations == 10


def test_parse_args_with_auto():
    """CLI should parse --auto flag."""
    args = parse_args(["--auto", "Generate tests"])

    assert args.task == "Generate tests"
    assert args.auto is True


@patch('ralph_loop.cli.RalphLoop')
def test_main_creates_loop(mock_loop_class):
    """CLI main should create and run RalphLoop."""
    mock_loop = Mock()
    mock_loop.run.return_value = {
        "final_success": True,
        "total_iterations": 2
    }
    mock_loop_class.return_value = mock_loop

    with patch('sys.argv', ['ralph-loop', 'Test task']):
        exit_code = main()

    assert exit_code == 0
    assert mock_loop.run.called


@patch('ralph_loop.cli.RalphLoop')
def test_main_returns_error_on_failure(mock_loop_class):
    """CLI should return non-zero exit code on failure."""
    mock_loop = Mock()
    mock_loop.run.return_value = {
        "final_success": False,
        "total_iterations": 5
    }
    mock_loop_class.return_value = mock_loop

    with patch('sys.argv', ['ralph-loop', 'Test task']):
        exit_code = main()

    assert exit_code == 1
