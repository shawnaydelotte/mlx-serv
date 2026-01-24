"""Review phase - validate execution results."""

import re
from typing import List, Dict, Any
from ralph_loop.api_client import RalphAPIClient


class ReviewPhase:
    """Reviews execution results against success criteria."""

    SYSTEM_PROMPT = """You are a code review assistant validating implementation results.

Given an implementation plan and execution results, evaluate:

1. **Criteria Met**: Check each success criterion
2. **Success**: Overall yes/no - are we done?
3. **Next Steps**: If not done, what should happen next?

Format response as markdown with clear sections."""

    def __init__(self, client: RalphAPIClient):
        """
        Initialize review phase.

        Args:
            client: API client for LLM communication
        """
        self.client = client

    def review_execution(
        self,
        plan: str,
        execution_results: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Review execution results against plan.

        Args:
            plan: Original implementation plan
            execution_results: Results from execute phase

        Returns:
            Review summary with success status and next steps
        """
        prompt = f"""# Implementation Plan

{plan}

# Execution Results

{self._format_results(execution_results)}

Please review the execution results and determine if the success criteria are met."""

        review_text = self.client.send_message(prompt, system=self.SYSTEM_PROMPT)

        # Parse review
        success = self._extract_success(review_text)
        next_steps = self._extract_next_steps(review_text)

        return {
            "success": success,
            "review_text": review_text,
            "criteria_met": self._extract_criteria(review_text),
            "next_steps": next_steps
        }

    def _format_results(self, results: List[Dict[str, Any]]) -> str:
        """Format execution results as markdown."""
        lines = []
        for r in results:
            status_icon = "✓" if r["status"] in ["executed", "simulated"] else "✗"
            lines.append(f"{status_icon} Step {r['step_number']}: {r['step']}")
        return "\n".join(lines)

    def _extract_success(self, review_text: str) -> bool:
        """Extract success status from review."""
        # Look for "Success: Yes" or "Success: No"
        match = re.search(r'Success:\s*(Yes|No)', review_text, re.IGNORECASE)
        if match:
            return match.group(1).lower() == 'yes'

        # Default to False if unclear
        return False

    def _extract_criteria(self, review_text: str) -> List[str]:
        """Extract met criteria from review."""
        criteria = []

        in_criteria = False
        for line in review_text.split('\n'):
            if 'Criteria Met' in line or 'criteria met' in line.lower():
                in_criteria = True
                continue

            if in_criteria and line.strip().startswith('##'):
                break

            if in_criteria and line.strip().startswith('✓'):
                criteria.append(line.strip())

        return criteria

    def _extract_next_steps(self, review_text: str) -> List[str]:
        """Extract next steps from review."""
        steps = []

        in_next_steps = False
        for line in review_text.split('\n'):
            if 'Next Steps' in line or 'next steps' in line.lower():
                in_next_steps = True
                continue

            if in_next_steps and line.strip().startswith('##'):
                break

            if in_next_steps:
                match = re.match(r'^\d+\.\s+(.+)$', line.strip())
                if match:
                    steps.append(match.group(1))

        return steps
