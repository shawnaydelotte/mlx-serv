"""Main Ralph Loop orchestration."""

from pathlib import Path
from typing import Optional, Dict, Any

from ralph_loop.state import StateManager
from ralph_loop.model_selector import ModelSelector
from ralph_loop.api_client import RalphAPIClient
from ralph_loop.phases import PlanPhase, ExecutePhase, ReviewPhase


class RalphLoop:
    """Autonomous iteration engine for coding tasks."""

    def __init__(
        self,
        task_description: str,
        ralph_dir: Path = None,
        model: Optional[str] = None,
        max_iterations: int = 5,
        auto_approve: bool = False,
        base_url: str = "http://localhost:4000"
    ):
        """
        Initialize Ralph Loop.

        Args:
            task_description: Description of coding task
            ralph_dir: Directory for state/logs (default: .ralph/)
            model: Force model selection ("3b" or "7b"), None for auto
            max_iterations: Maximum iteration limit
            auto_approve: Skip user approval checkpoints
            base_url: LiteLLM server URL
        """
        self.task_description = task_description
        self.max_iterations = max_iterations
        self.auto_approve = auto_approve

        # Set up directories
        if ralph_dir is None:
            ralph_dir = Path.cwd() / ".ralph"
        self.ralph_dir = Path(ralph_dir)

        # Initialize state management
        self.state_manager = StateManager(self.ralph_dir)
        state = self.state_manager.load()
        state["max_iterations"] = max_iterations
        self.state_manager.save(state)

        # Select model
        if model is None:
            selector = ModelSelector()
            model = selector.select_model(task_description)

        self.model = model

        # Initialize API client
        self.client = RalphAPIClient(base_url=base_url, model=model)

        # Initialize phases
        self.plan_phase = PlanPhase(self.client)
        self.execute_phase = ExecutePhase(self.client, simulation=True)
        self.review_phase = ReviewPhase(self.client)

    def should_continue(self) -> bool:
        """Check if loop should continue iterating."""
        state = self.state_manager.load()
        return state["iteration"] < state["max_iterations"]

    def run_iteration(self) -> Dict[str, Any]:
        """
        Run single Plan → Execute → Review cycle.

        Returns:
            Iteration results with success status
        """
        state = self.state_manager.load()

        # Increment iteration
        self.state_manager.increment_iteration()
        state = self.state_manager.load()

        # Plan phase
        self.state_manager.set_phase("plan")
        plan = self.plan_phase.generate_plan(
            self.task_description,
            save_to=self.ralph_dir / "current-plan.md"
        )
        steps = self.plan_phase.extract_steps(plan)

        # Execute phase
        self.state_manager.set_phase("execute")
        execution_results = self.execute_phase.execute_steps(steps)

        # Review phase
        self.state_manager.set_phase("review")
        review = self.review_phase.review_execution(plan, execution_results)

        # Save results
        result = {
            "iteration": state["iteration"],
            "success": review["success"],
            "plan": plan,
            "steps": steps,
            "execution_results": execution_results,
            "review": review
        }

        self.state_manager.add_result(result)

        return result

    def run(self) -> Dict[str, Any]:
        """
        Run full Ralph Loop until completion or max iterations.

        Returns:
            Final results
        """
        results = []

        while self.should_continue():
            iteration_result = self.run_iteration()
            results.append(iteration_result)

            # Check if done
            if iteration_result["success"]:
                break

            # Checkpoint every 2 iterations (unless auto-approve)
            if not self.auto_approve and len(results) % 2 == 0:
                # Would prompt user here - for now just continue
                pass

        return {
            "task": self.task_description,
            "iterations": results,
            "final_success": results[-1]["success"] if results else False,
            "total_iterations": len(results)
        }
