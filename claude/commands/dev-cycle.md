---
description: Run one iteration of the autonomous development loop. Orchestrates tech-lead, planner, task execution, qa, status, and pm agents in sequence. Updates docs/loop-state.md with iteration progress.
---

# Dev Cycle — One Iteration

You are the orchestrator of one autonomous development iteration. Execute the following phases in order. After each phase, record progress in `docs/loop-state.md` before continuing.

## Setup

First, read `docs/loop-state.md` if it exists to understand the current iteration number and any carry-over context from the previous cycle. If it doesn't exist, this is iteration 1.

Read `docs/prd/index.md` and `docs/architecture.md` to orient yourself.

---

## Phase 1: Architecture Review

Spawn a `tech-lead` subagent:

```
Prompt: "Review the current project state and update docs/architecture.md.
Focus on: are there design gaps relative to the PRDs? Are there
architectural decisions that need to be made before the next round of
implementation? Read docs/prd/index.md, active PRDs under docs/prd/,
docs/status.md, and the codebase. Update docs/architecture.md and return
a summary of:
1. What architectural decisions were made or updated
2. What constraints the planner should know about
3. Any blockers that require user input before work can proceed"
```

If tech-lead reports a **blocker requiring user input**, stop the loop, update `docs/loop-state.md` with status `blocked`, and notify the user with the blocker details.

---

## Phase 2: Task Planning

Spawn a `planner` subagent:

```
Prompt: "Based on the current project state, update docs/tasks.md with
the next round of tasks. Read docs/prd/index.md and active PRDs under
docs/prd/, docs/architecture.md, docs/status.md, and docs/qa-report.md
(if it exists — qa failures should become tasks). Prioritize: fixing
failing tests first, then implementing the highest-value unfinished CUJs.
Return a summary of what tasks were scheduled and how many parallel groups
there are."
```

If planner reports nothing left to do (all CUJs implemented and tests passing), proceed to Phase 6 (Final Evaluation) instead.

---

## Phase 3: Task Execution

Read `docs/tasks.md`. For each parallel group, spawn all tasks simultaneously as background worktree agents:
- `isolation: "worktree"` — each agent gets its own branch
- `run_in_background: true` — parallel execution
- Each agent's prompt must be fully self-contained with task description, file paths, and acceptance criteria
- Each agent commits its work when done

**All agents in a group must be spawned in a single message.**

Wait for all agents in the group to complete before moving to the next group. If any agent fails, note the failure and continue with remaining groups — do not abort the cycle.

---

## Phase 4: QA

Spawn a `qa` subagent:

```
Prompt: "Run the full test suite, identify coverage gaps for implemented
features, write missing tests, run again, and produce docs/qa-report.md.
Focus on verifying that implemented features match their PRD specs. Read
docs/prd/index.md and active PRDs under docs/prd/ for the CUJ acceptance
criteria to test against."
```

---

## Phase 5: Status Update

Spawn a `status` subagent:

```
Prompt: "Read the full project state and update docs/status.md.
Include: what's implemented, what's in progress, what's planned,
recent changes from git log, and any known issues."
```

---

## Phase 6: PM Review

Spawn a `pm` subagent:

```
Prompt: "Review docs/status.md and docs/qa-report.md against the active
PRDs under docs/prd/. Walk each CUJ step by step against the actual
implementation. Identify: what CUJs are fully satisfied, what needs
adjustment based on what was actually built, and what gaps remain.
Update the relevant PRD files and docs/prd/index.md to reflect any
refinements. Return a summary of what changed and what still needs
to be done."
```

---

## Phase 7: Final Evaluation

Spawn a `tech-lead` subagent:

```
Prompt: "Review docs/prd/index.md, active PRDs under docs/prd/,
docs/status.md, docs/qa-report.md, and docs/architecture.md. Assess:
are all CUJs in active PRDs implemented and verified by passing tests?
Are there any architectural issues that must be resolved? Return one of
three verdicts:
- DONE: all CUJs satisfied, all tests passing, no blockers
- CONTINUE: progress was made, more work remains, safe to iterate
- BLOCKED: cannot proceed without user input — describe exactly what is needed"
```

---

## Phase 8: Update Loop State

Write `docs/loop-state.md`:

```markdown
# Dev Loop State

Last updated: <date>
Iteration: <N>
Status: <continue | done | blocked>

## Last Cycle Summary
- Tasks executed: <count>
- Tests passing: <count>
- Tests failing: <count>
- CUJs completed this cycle: <list>
- CUJs remaining: <count>

## Blocker (if status = blocked)
<description of what requires user input>

## Next Focus
<what the next iteration should prioritize>
```

---

## Exit Conditions

- **Status = `done`**: Report to the user that all CUJs are implemented and verified. List what was accomplished across all iterations. Stop the loop.
- **Status = `blocked`**: Report the blocker clearly to the user. Stop the loop and wait for their input.
- **Status = `continue`**: Report the iteration summary (tasks done, test results, what remains). The loop continues to the next iteration.
