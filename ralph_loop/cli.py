"""Command-line interface for Ralph Loop."""

import argparse
import sys
from pathlib import Path
from typing import List

from ralph_loop.loop import RalphLoop


def parse_args(argv: List[str] = None) -> argparse.Namespace:
    """
    Parse command-line arguments.

    Args:
        argv: Argument list (default: sys.argv[1:])

    Returns:
        Parsed arguments
    """
    parser = argparse.ArgumentParser(
        description="Ralph Loop - Autonomous iteration engine for coding tasks"
    )

    parser.add_argument(
        "task",
        help="Description of the coding task"
    )

    parser.add_argument(
        "--model",
        choices=["3b", "7b"],
        help="Force model selection (default: auto-select based on task)"
    )

    parser.add_argument(
        "--max-iterations",
        type=int,
        default=5,
        help="Maximum number of iterations (default: 5)"
    )

    parser.add_argument(
        "--auto",
        action="store_true",
        help="Skip user approval checkpoints"
    )

    parser.add_argument(
        "--ralph-dir",
        type=Path,
        default=Path.cwd() / ".ralph",
        help="Directory for state and logs (default: .ralph/)"
    )

    return parser.parse_args(argv)


def main() -> int:
    """
    Main entry point for CLI.

    Returns:
        Exit code (0 for success, 1 for failure)
    """
    args = parse_args()

    print(f"🔁 Ralph Loop")
    print(f"Task: {args.task}")
    print(f"Model: {args.model or 'auto-select'}")
    print(f"Max iterations: {args.max_iterations}")
    print()

    # Create and run loop
    loop = RalphLoop(
        task_description=args.task,
        ralph_dir=args.ralph_dir,
        model=args.model,
        max_iterations=args.max_iterations,
        auto_approve=args.auto
    )

    try:
        results = loop.run()

        # Print summary
        print()
        print("=" * 50)
        if results["final_success"]:
            print("✓ Task completed successfully!")
        else:
            print("✗ Task not completed (reached max iterations)")

        print(f"Total iterations: {results['total_iterations']}")
        print(f"State saved to: {args.ralph_dir}")

        return 0 if results["final_success"] else 1

    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted by user")
        print(f"State saved to: {args.ralph_dir}")
        print("Run again to resume from last checkpoint")
        return 130

    except Exception as e:
        print(f"\n\n❌ Error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
