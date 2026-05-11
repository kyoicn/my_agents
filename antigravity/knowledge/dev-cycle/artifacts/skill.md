# dev-cycle Command Instructions


# Dev Cycle — One Iteration

You are the orchestrator of one autonomous development iteration. Execute the following phases in order. After each phase, record progress in `docs/loop-state.md` before continuing.

## Setup

First, check if the user specified a **target PRD** (e.g., `dev-cycle prd-008`). If they did, this cycle is **scoped** — all phases only work against that single PRD file (`docs/prd/prd-008-*.md`). If no target is specified, the cycle works against all active PRDs.

Throughout these instructions:
- **Scoped mode**: replace every mention of "active PRDs under docs/prd/" with the specific target PRD file path. Subagent prompts must name the exact file so agents don't wander into unrelated PRDs.
- **Unscoped mode**: use all active PRDs as before.

Next, read `docs/loop-state.md` if it exists to understand the current iteration number and any carry-over context from the previous cycle. **Pay special attention to the QA Gate section** — if the previous iteration ended with QA FAIL, this iteration's Planner must prioritize fixing those failures before taking on new work.

Read `docs/prd/index.md` and all files under `docs/design/` to orient yourself.

### Guidelines Discovery

Run `ls docs/*-guidelines.md 2>/dev/null` to check for guideline files. If any `*-guidelines.md` files exist, read all of them before proceeding — they contain mandatory development and process rules that apply to every phase of this cycle. Store the list of discovered file paths and pass them to every subagent prompt below. If no guideline files exist, skip this step and proceed normally.

---

## Phase 1: Architecture Review

Spawn a `tl` subagent:

```
Prompt: "Review the current project state and update docs/design/.
Focus on: are there design gaps relative to the PRDs? Are there
design decisions that need to be made before the next round of
implementation? Read docs/prd/index.md, active PRDs under docs/prd/,
all files under docs/design/, docs/status.md, and the codebase.
Update the appropriate design docs (system.md for cross-cutting,
design-<slug>.md for component-specific) and return a summary of:
1. What design decisions were made or updated
2. What constraints the planner should know about
3. Any blockers that require user input before work can proceed"
```

If tl reports a **blocker requiring user input**, stop the loop, update `docs/loop-state.md` with status `blocked`, and notify the user with the blocker details.

---

## Phase 2: Task Planning

Spawn a `planner` subagent:

```
Prompt: "Based on the current project state, update docs/tasks.md with
the next round of tasks. Read docs/prd/index.md and active PRDs under
docs/prd/, all files under docs/design/, docs/status.md, and docs/qa-report.md
(if it exists — qa failures and fabrications MUST become fix tasks with
highest priority). Prioritize in this order:
1. Fix QA FABRICATION items (fake data, no-op stubs, unexecuted pipelines)
2. Fix QA FAIL items (bugs and regressions)
3. Implement the highest-value unfinished CUJs
Never schedule new feature work if unresolved QA FAIL items exist.
Return a summary of what tasks were scheduled and how many parallel groups
there are."
```

If planner reports nothing left to do (all CUJs in scope implemented and tests passing), proceed to Phase 6 (PM Review) instead.

---

## Phase 3: Task Execution

Read `docs/tasks.md`. For each parallel group, spawn all tasks simultaneously as background worktree agents:
- `isolation: "worktree"` — each agent gets its own branch
- `run_in_background: true` — parallel execution
- Each agent's prompt must be fully self-contained with task description, file paths, and acceptance criteria
- If any `docs/*-guidelines.md` files were discovered in Setup, each agent's prompt must include: "Read all docs/*-guidelines.md files before starting. Your code and process must comply with every rule in those documents."
- Each agent commits its work when done

**All agents in a group must be spawned in a single message.**

Wait for all agents in the group to complete before moving to the next group. If any agent fails, note the failure and continue with remaining groups — do not abort the cycle.

### Phase 3.5: Merge & Resolve Conflicts

After all groups complete:
1. Merge each agent's branch into the main branch in group order (Group 1 first, then Group 2, etc.)
2. Within each group, merge in the order tasks appear in `docs/tasks.md`
3. If a merge conflict occurs:
   - Attempt automatic resolution for trivial conflicts (import additions, non-overlapping changes)
   - For non-trivial conflicts, note the conflict in loop-state.md and attempt resolution by reading both changes and combining them
4. After all merges, run the project's compilation/type-check command (e.g., `npx tsc --noEmit`, `cargo check`, `go build ./...`, `python -m py_compile`) to verify the combined code compiles. If it fails, fix compilation errors before proceeding.

---

### Phase 3.6: Code Review

Spawn a `tl` subagent:

```
Prompt: "Conduct a code quality review of all changes made in this
iteration. Use git diff to identify changed files. Execute your
code review checklist (Section 4 of your role definition):
- Type safety: run the project's type checker, search for weak type annotations
- Architecture: verify framework rules, state management patterns
- Security: check for hardcoded secrets, open CORS, missing auth
- Performance: check for unthrottled I/O, N+1 queries, missing virtualization
- Configuration: check for hardcoded values that should be constants
- Guideline compliance: if any docs/*-guidelines.md files exist, verify
  all changed code complies

Fix simple, unambiguous issues directly (unused imports, type annotations,
hardcoded values → constants). For design-level issues, flag them but do
not modify the code.

Produce a code review summary and commit any fixes you made."
```

If TL finds critical issues that could not be auto-fixed, note them in `docs/loop-state.md`. These will be picked up by QA as part of the overall quality assessment.

---

## Phase 4: QA Gate

**This is the most critical phase. QA is a gate, not just a reporter.**

Spawn a `qa` subagent:

```
Prompt: "You are the quality gate for this iteration. Your verdict
determines whether work is accepted or rejected.

Execute ALL of your steps including Step 9 (gate enforcement):
1. Run the full test suite and capture results
2. Map coverage to CUJ acceptance criteria from active PRDs under docs/prd/
3. Write missing integration/E2E tests for implemented features
4. Run all tests again
5. Perform MANDATORY manual verification — start the app and walk every CUJ
6. Execute the fabrication detection checklist on EVERY claimed feature
7. Write docs/qa-report.md with per-CUJ verdicts
8. **ENFORCE THE GATE (Step 9)**: Update docs/tasks.md — roll back any
   task marked [x] that failed verification to [ ] with a QA FAIL note.
   Add new fix tasks for every bug found. Update docs/loop-state.md with
   your QA Gate verdict.

Read docs/prd/index.md and active PRDs under docs/prd/ for the CUJ
acceptance criteria. If any docs/*-guidelines.md files exist, read them
for the definition of 'done' — apply it strictly."
```

### After QA completes:

Read `docs/qa-report.md` and check the verdict:

- **QA PASS**: Continue to Phase 5.
- **QA FAIL with only LOW/MEDIUM bugs**: Continue to Phase 5 (bugs will be picked up next iteration).
- **QA FAIL with HIGH bugs or FABRICATION**: **Do NOT continue to Phase 5.** Instead:
  1. Log the failures in `docs/loop-state.md`
  2. Jump back to **Phase 2** (re-plan with QA failures as priority tasks)
  3. Re-execute **Phase 3** (fix the issues)
  4. Re-execute **Phase 4** (re-verify)
  5. Maximum 2 QA retry loops per iteration. If still failing after 2 retries, mark status as `blocked` with QA details and stop.

This inner loop ensures critical bugs and fabrications are fixed within the same iteration, not deferred indefinitely.

---

## Phase 5: Status Update

Spawn a `status` subagent:

```
Prompt: "Read the full project state and update docs/status.md.
Include: what's implemented, what's in progress, what's planned,
recent changes from git log, and any known issues.
IMPORTANT: Cross-reference your findings with docs/qa-report.md.
If QA marked a feature as FAIL or FABRICATION, do NOT list it as
'implemented' in status.md — list it as 'in-progress' with the
QA finding noted."
```

---

## Phase 6: PM Review

Spawn a `pm` subagent:

```
Prompt: "Review docs/status.md and docs/qa-report.md against the active
PRDs under docs/prd/. Walk each CUJ step by step against the actual
implementation. Identify: what CUJs are fully satisfied, what needs
adjustment based on what was actually built, and what gaps remain.
IMPORTANT: If QA verdict was FAIL, do NOT mark any failed CUJ as
complete in the PRD files. Only mark CUJs as [x] if QA explicitly
passed them. Update the relevant PRD files and docs/prd/index.md.
Return a summary of what changed and what still needs to be done."
```

---

## Phase 7: Final Evaluation

Spawn a `tl` subagent:

```
Prompt: "Review docs/prd/index.md, active PRDs under docs/prd/,
docs/status.md, docs/qa-report.md, and all files under docs/design/.

Your verdict MUST be consistent with the QA report:
- If docs/qa-report.md verdict is FAIL, you CANNOT return DONE.
- If any FABRICATION items were found by QA, you CANNOT return DONE.

Assess: are all CUJs in active PRDs implemented and verified by
QA with a PASS verdict? Are there any architectural issues that
must be resolved? Return one of three verdicts:
- DONE: all CUJs satisfied, QA PASS, no blockers
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
- Tasks passed QA: <count>
- Tasks rolled back by QA: <count> (<list task names>)
- Tests passing: <count>
- Tests failing: <count>
- QA inner loops used: <0-2>
- CUJs completed this cycle: <list>
- CUJs remaining: <count>

## QA Gate
- Verdict: <PASS | FAIL>
- Fabrications found: <count> (<brief list or "none">)
- HIGH bugs found: <count>
- Tasks rolled back: <list of task names set back to in-progress>

## Blocker (if status = blocked)
<description of what requires user input>

## Next Focus
<what the next iteration should prioritize — include unresolved QA items>
```

---

## Exit Conditions

- **Status = `done`**: Report to the user that all CUJs in scope are implemented and verified by QA. List what was accomplished across all iterations. Stop the loop.
- **Status = `blocked`**: Report the blocker clearly to the user. Stop the loop and wait for their input.
- **Status = `continue`**: Report the iteration summary (tasks done, QA verdict, test results, what remains). The loop continues to the next iteration.
