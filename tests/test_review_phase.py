"""Tests for Review phase."""

import pytest
from unittest.mock import Mock
from ralph_loop.phases.review import ReviewPhase


def test_review_phase_initialization():
    """Review phase should initialize with API client."""
    mock_client = Mock()
    phase = ReviewPhase(mock_client)

    assert phase.client == mock_client


def test_review_phase_checks_success_criteria():
    """Review phase should evaluate success criteria."""
    mock_client = Mock()
    mock_client.send_message.return_value = """
# Review Results

## Criteria Met

✓ All tests pass (15/15)
✓ No new errors introduced
✓ Code follows project style

## Success: Yes

The implementation meets all success criteria.
"""

    phase = ReviewPhase(mock_client)

    plan = "## Success Criteria\n- All tests pass\n- No errors"
    results = [{"step": "Fix bug", "status": "executed", "step_number": 1}]

    review = phase.review_execution(plan, results)

    assert review["success"] is True
    assert "criteria_met" in review
    assert mock_client.send_message.called


def test_review_phase_detects_failure():
    """Review phase should detect when criteria not met."""
    mock_client = Mock()
    mock_client.send_message.return_value = """
# Review Results

## Criteria Met

✗ Tests failing (12/15 pass)
✓ No new errors

## Success: No

Tests still failing - need to investigate further.
"""

    phase = ReviewPhase(mock_client)

    plan = "## Success Criteria\n- All tests pass"
    results = [{"step": "Fix bug", "status": "executed", "step_number": 1}]

    review = phase.review_execution(plan, results)

    assert review["success"] is False


def test_review_phase_extracts_next_steps():
    """Review phase should extract recommended next steps."""
    mock_client = Mock()
    mock_client.send_message.return_value = """
# Review Results

## Success: No

## Next Steps

1. Check error logs for root cause
2. Add more detailed debugging
3. Verify edge cases
"""

    phase = ReviewPhase(mock_client)

    plan = "## Success Criteria\n- All tests pass"
    results = [{"step": "Fix bug", "status": "executed", "step_number": 1}]

    review = phase.review_execution(plan, results)

    assert "next_steps" in review
    assert len(review["next_steps"]) == 3
