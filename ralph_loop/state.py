"""State management for Ralph Loop iterations."""

import json
from pathlib import Path
from typing import Any, Dict


class StateManager:
    """Manages iteration state with persistence to .ralph/state.json"""

    def __init__(self, ralph_dir: Path):
        self.ralph_dir = Path(ralph_dir)
        self.ralph_dir.mkdir(parents=True, exist_ok=True)
        self.state_file = self.ralph_dir / "state.json"

        # Initialize if doesn't exist
        if not self.state_file.exists():
            self._write_state(self._initial_state())

    def _initial_state(self) -> Dict[str, Any]:
        """Return initial empty state."""
        return {
            "iteration": 0,
            "phase": "plan",
            "plan": None,
            "results": [],
            "max_iterations": 5
        }

    def _read_state(self) -> Dict[str, Any]:
        """Read state from disk."""
        with open(self.state_file, 'r') as f:
            return json.load(f)

    def _write_state(self, state: Dict[str, Any]) -> None:
        """Write state to disk."""
        with open(self.state_file, 'w') as f:
            json.dump(state, f, indent=2)

    def load(self) -> Dict[str, Any]:
        """Load current state."""
        return self._read_state()

    def save(self, state: Dict[str, Any]) -> None:
        """Save complete state."""
        self._write_state(state)

    def increment_iteration(self) -> None:
        """Increment iteration counter."""
        state = self.load()
        state["iteration"] += 1
        self.save(state)

    def set_phase(self, phase: str) -> None:
        """Update current phase."""
        state = self.load()
        state["phase"] = phase
        self.save(state)

    def add_result(self, result: Dict[str, Any]) -> None:
        """Append iteration result."""
        state = self.load()
        state["results"].append(result)
        self.save(state)

    def reset(self) -> None:
        """Reset to initial state."""
        self.save(self._initial_state())
