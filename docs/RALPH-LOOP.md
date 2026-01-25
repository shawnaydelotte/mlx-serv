# Ralph Loop Tutorial

Ralph Loop is an autonomous iteration engine that helps complete coding tasks through structured Plan → Execute → Review → Refine cycles.

## Quick Start

```bash
# Start the MLX servers
./start.sh

# Run Ralph Loop on a task
./ralph-loop.sh "Fix authentication bug in login.py"

# Force 3B model for speed
./ralph-loop.sh --model 3b "Add unit tests for API endpoints"

# Skip approval checkpoints
./ralph-loop.sh --auto "Format all Python files"
```

## How It Works

Ralph Loop runs in four phases:

### 1. Plan Phase

The model analyzes your task and generates a detailed implementation plan with:
- Numbered steps to complete
- Success criteria to validate completion
- Files to read/modify

**Example Plan:**

```markdown
# Implementation Plan

## Steps

1. Read authentication.py to understand current implementation
2. Write a test that reproduces the login bug
3. Run the test to verify it fails
4. Implement the fix in authentication.py
5. Run the test to verify it passes
6. Run full test suite to check for regressions

## Success Criteria

- New test reproduces the bug
- Test passes after fix
- All existing tests still pass
- No new errors introduced
```

### 2. Execute Phase

The model executes each step from the plan:
- Reads relevant files
- Writes/modifies code
- Runs tests
- Checks for errors

**Current Status:** Simulation mode - logs intent without making actual changes. Full execution requires OpenCode tool integration.

### 3. Review Phase

The model evaluates execution results against success criteria:
- Checks each criterion
- Determines if task is complete
- Identifies next steps if not done

### 4. Refine Phase

Based on review results:
- **If successful:** Loop exits, task complete
- **If not successful:** Generate refined plan and iterate
- **If max iterations reached:** Stop and report status

## Command-Line Options

```bash
./ralph-loop.sh [OPTIONS] "task description"

Options:
  --model 3b|7b           Force model selection (default: auto)
  --max-iterations N      Max iteration limit (default: 5)
  --auto                  Skip approval checkpoints
  --ralph-dir DIR         State directory (default: .ralph/)
```

## Model Selection

Ralph Loop automatically selects the best model for your task:

**3B Model (Fast - 300-400 tok/s):**
- Format code
- Add comments/docstrings
- Generate tests
- Fix typos
- Rename variables

**7B Model (Quality - 150-200 tok/s):**
- Refactor architecture
- Debug complex issues
- Optimize algorithms
- Design APIs
- Security fixes

**Manual Override:**
```bash
# Force 3B for speed
./ralph-loop.sh --model 3b "refactor authentication"

# Force 7B for quality
./ralph-loop.sh --model 7b "add unit tests"
```

## State Management

All state is saved in `.ralph/` directory:

```
.ralph/
├── state.json           # Current iteration, phase, results
├── current-plan.md      # Active implementation plan
```

**Resume from checkpoint:**

```bash
# State persists - just run again
./ralph-loop.sh "same task description"
```

**Reset state:**

```bash
rm -rf .ralph/
```

## Examples

### Example 1: Bug Fix

```bash
./ralph-loop.sh "Fix the timeout issue in API client"
```

Ralph Loop will:
1. Read the API client code
2. Identify the timeout configuration
3. Write a test that reproduces the issue
4. Fix the timeout handling
5. Verify tests pass

### Example 2: Refactoring

```bash
./ralph-loop.sh --model 7b "Refactor authentication to use JWT tokens"
```

Ralph Loop will:
1. Analyze current authentication system
2. Design JWT token architecture
3. Implement token generation/validation
4. Update authentication middleware
5. Add comprehensive tests
6. Verify no regressions

### Example 3: Test Generation

```bash
./ralph-loop.sh --model 3b "Generate unit tests for database.py"
```

Ralph Loop will:
1. Read database.py to understand functions
2. Generate test cases for each function
3. Add edge case tests
4. Run tests to verify they work
5. Achieve good coverage

## Troubleshooting

### "Error: Virtual environment not found"

```bash
./setup.sh
```

### "Warning: LiteLLM server not running"

Ralph Loop automatically starts servers, but you can manually start:

```bash
./start.sh
```

### "Loop not making progress"

Reduce max iterations and review results:

```bash
./ralph-loop.sh --max-iterations 2 "task description"
```

### "Out of memory"

Use 3B model:

```bash
./ralph-loop.sh --model 3b "task description"
```

## Advanced Usage

### Custom State Directory

```bash
./ralph-loop.sh --ralph-dir /tmp/ralph-experiment "task"
```

### Scripting with Ralph Loop

```python
from ralph_loop import RalphLoop

loop = RalphLoop(
    task_description="Optimize query performance",
    model="7b",
    max_iterations=10,
    auto_approve=True
)

results = loop.run()

if results["final_success"]:
    print("Task completed!")
else:
    print(f"Stopped after {results['total_iterations']} iterations")
```

## Limitations

### Current Limitations

1. **Simulation Mode:** Execute phase logs actions but doesn't modify files
2. **No Tool Calling:** Can't actually run git, tests, or read files
3. **No Codebase Context:** Doesn't know about project structure

### Future Enhancements

- OpenCode tool integration for real execution
- File system operations (read, write, execute)
- Git integration (commit, branch, diff)
- Test runner integration
- Code analysis tools

## Performance

**Iteration Times (M2 Max):**

| Phase | 3B Model | 7B Model |
|-------|----------|----------|
| Plan | 10-15s | 20-30s |
| Execute | 5-10s | 10-15s |
| Review | 5-10s | 10-15s |
| **Total** | **20-35s** | **40-60s** |

**Typical Tasks:**

- Simple tasks: 1-2 iterations (< 2 minutes with 3B)
- Medium tasks: 2-4 iterations (< 5 minutes with 7B)
- Complex tasks: 3-5 iterations (< 8 minutes with 7B)

## Best Practices

1. **Be specific in task descriptions**
   - Good: "Fix timeout in API client (timeout should be 30s not 10s)"
   - Bad: "Fix API issues"

2. **Use appropriate model**
   - 3B for formatting, comments, simple tests
   - 7B for logic, refactoring, architecture

3. **Start with low max-iterations**
   - Use `--max-iterations 2` to preview behavior
   - Increase if making good progress

4. **Reset state between unrelated tasks**
   - `rm -rf .ralph/` before starting new task
   - Prevents context pollution

## FAQ

**Q: Does Ralph Loop modify my code?**

A: Currently no - it runs in simulation mode. Full execution requires OpenCode tool integration.

**Q: Can I run multiple Ralph Loops in parallel?**

A: Not recommended - they share the same state directory (`.ralph/`). Use `--ralph-dir` for separate instances.

**Q: How do I know which model was used?**

A: Check the initial output or state file.

**Q: Can Ralph Loop use MCP servers?**

A: Not yet - MCP integration is planned for future versions.

---

For more information:
- Main README: `README.md`
- Implementation Plan: `docs/plans/2026-01-24-ralph-loop-engine.md`
