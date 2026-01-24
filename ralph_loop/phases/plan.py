"""Plan phase - analyze task and generate implementation plan."""

import re
from pathlib import Path
from typing import List, Optional
from ralph_loop.api_client import RalphAPIClient


class PlanPhase:
    """Generates structured implementation plans for coding tasks."""

    SYSTEM_PROMPT = """You are a software engineering assistant helping to plan coding tasks.

When given a task description, generate a detailed implementation plan with:

1. **Steps**: Numbered list of specific actions to take
2. **Success Criteria**: Clear conditions that indicate completion

Format your response as markdown with ## Steps and ## Success Criteria sections.
Be specific about files to read, tests to write, and validation steps."""

    def __init__(self, client: RalphAPIClient):
        """
        Initialize plan phase.

        Args:
            client: API client for LLM communication
        """
        self.client = client

    def generate_plan(self, task_description: str, save_to: Optional[Path] = None) -> str:
        """
        Generate implementation plan for a task.

        Args:
            task_description: Description of coding task
            save_to: Optional path to save plan

        Returns:
            Generated plan as markdown
        """
        prompt = f"""Task: {task_description}

Please generate a detailed implementation plan for this task."""

        plan = self.client.send_message(prompt, system=self.SYSTEM_PROMPT)

        # Save to file if requested
        if save_to:
            save_to.parent.mkdir(parents=True, exist_ok=True)
            save_to.write_text(plan)

        return plan

    def extract_steps(self, plan: str) -> List[str]:
        """
        Extract numbered steps from plan.

        Args:
            plan: Plan markdown text

        Returns:
            List of step descriptions
        """
        steps = []

        # Find the Steps section
        in_steps = False
        for line in plan.split('\n'):
            if '## Steps' in line or '## steps' in line.lower():
                in_steps = True
                continue

            # Stop at next section
            if in_steps and line.strip().startswith('##'):
                break

            # Extract numbered items
            if in_steps:
                match = re.match(r'^\d+\.\s+(.+)$', line.strip())
                if match:
                    steps.append(match.group(1))

        return steps
