---
description: Run one iteration of the autonomous development loop. Orchestrates tl, planner, task execution, qa, status, and pm agents in sequence. Updates docs/loop-state.md with iteration progress.
---

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

### Worktree Label

Compute a short worktree label so this cycle's subagents are distinguishable from any other Claude sessions running on the same repo (e.g., another `/dev-cycle` running from a different worktree, or the user editing in a parallel window). The label flows into FleetView via each subagent's `description` parameter.

Steps:
1. Run `git worktree list --porcelain` and find the entry whose `branch` is `refs/heads/main` (or `refs/heads/master`). The `worktree` line gives the main worktree's absolute path; take its basename — call it `<main-basename>` (e.g., `my_agents`).
2. Get the current cwd's basename via `basename "$(pwd)"` — call it `<cwd-basename>`.
3. Derive `<worktree-label>`:
   - If `<cwd-basename>` equals `<main-basename>`: label is `main`.
   - If `<cwd-basename>` starts with `<main-basename>-`: label is the suffix after the `-` (e.g., `data` for `my_agents-data`, `ui` for `my_agents-ui`).
   - Otherwise: label is `<cwd-basename>` itself (fallback for non-conventional paths).

**Every Agent tool call this skill makes in subsequent phases must prefix its `description` parameter with `<worktree-label>: `.** Examples (running from `my_agents-data`, label = `data`):

| Without prefix | With prefix |
|---|---|
| `tl architecture review` | `data: tl architecture review` |
| `planner: next round` | `data: planner: next round` |
| `qa gate iteration 3` | `data: qa gate iteration 3` |
| `task: implement filter UI` | `data: task: implement filter UI` |

This applies to every subagent spawned by this skill — tl, planner, qa, status, pm, and every task-execution worker. It does not change anything inside the subagent's prompt body; only the `description` (the visible label).

---

## Mocks Check

Mocks are normally produced during `/design-feature` Phase 0.5 alongside CUJ shape iteration — every CUJ that exited `/design-feature` should already have at least one mock file under `docs/ux/<prd-dir>/`. This check surfaces any CUJ that's missing mocks (typically: backfilled PRDs from `/organize-project` that didn't go through `/design-feature`, or CUJs added by manual `/user:pm` invocation without the conversational mock flow).

1. Identify in-scope CUJs:
   - **Scoped mode**: CUJs in the target PRD
   - **Unscoped mode**: CUJs across all active PRDs

2. For each in-scope CUJ, glob `docs/ux/**/cuj-<id>-*.{html,png,jpg,webp,md}`.

3. If every in-scope CUJ has at least one matching mock file, print one line ("Mocks present for all in-scope CUJs.") and continue to Phase 1.

4. Otherwise, list the CUJs missing mocks and use `AskUserQuestion` to ask the user to choose:
   - **Proceed without fidelity check** — QA will log `NO_MOCK` for these CUJs and skip visual comparison; functional verification still runs.
   - **Pause** — stop the cycle here so mocks can be produced via `/design-feature` Route D (refine the affected CUJs to add mocks).

   The handoff is just the slash-command invocation:

   ```
   /design-feature
   ```

   Then describe to the orchestrator that you want to add mocks for CUJ-<X>, CUJ-<Y> in prd-NNN-<slug> (Route D — refine). The orchestrator will walk through each CUJ's shape (confirming it matches what's already specified), produce the mocks, and save them under `docs/ux/<prd-dir>/`.

5. If the user chooses **Pause**, mark `docs/loop-state.md` with status `blocked`, list the missing mocks under "Blocker", and stop. The user re-invokes `/dev-cycle` after running `/design-feature` to add the mocks.

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
(if it exists — every MEDIUM-or-higher bug must become a fix task with
priority above new feature work). Prioritize in this order:
1. Fix MEDIUM-or-higher bugs from docs/qa-report.md (any kind — BUG,
   REGRESSION, FABRICATION, FLAKY, VISUAL_DEVIATION). Severity drives
   priority, not kind: a [LOW][FABRICATION] is lower than a [HIGH][BUG].
2. Implement the highest-value unfinished CUJs.
3. Address LOW bugs from docs/qa-report.md as capacity allows.
Never schedule new feature work while any MEDIUM-or-higher bug remains
unresolved.
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

Read `docs/qa-report.md` and check the overall verdict plus bug severities. The verdict alone doesn't decide the loop — combine it with the severity distribution:

- **`PASS`** (no bugs): Continue to Phase 5.
- **`FAIL` with only `LOW` bugs across the entire report**: Continue to Phase 5. The LOW bugs are queued as next-iteration tasks (qa Step 9 already appended them).
- **`FAIL` with any bug of severity `MEDIUM` or higher** (any kind — `BUG`, `REGRESSION`, `FABRICATION`, `FLAKY`): **Do NOT continue to Phase 5.** Instead:
  1. Log the failures in `docs/loop-state.md`.
  2. Jump back to **Phase 2** (re-plan with QA-fix tasks as the priority).
  3. Re-execute **Phase 3** (fix the issues).
  4. Re-execute **Phase 4** (re-verify).
  5. Maximum 2 QA retry loops per iteration. If still failing after 2 retries, mark status as `blocked` with QA details and stop.
- **`BLOCKED`** (any CUJ Result is BLOCKED): Stop the loop, mark status as `blocked` in `docs/loop-state.md`, and surface the missing capability to the user. Do not retry — retries cannot fix a missing tool.

This inner loop ensures non-trivial bugs (MEDIUM+) are fixed within the same iteration, while LOW cosmetic issues flow forward without spinning the loop.

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

This is the product-side gate. The engineering team has produced an implementation; PM now answers "are all requirements satisfied?" — product judgment that QA doesn't make. PM does **not** mutate PRDs (PRDs are pure spec); they write `docs/pm-review.md` with a per-CUJ Satisfied / Caveats / Not done verdict.

Spawn a `pm` subagent:

```
Prompt: "Execute Section 6 (Review implemented work) of your role
definition. Walk every in-scope CUJ against the running implementation;
read docs/qa-report.md for the engineering-side verdict; produce a
product-side judgment per CUJ; write docs/pm-review.md following the
structure in your role definition.

You may also flip PRD frontmatter status: active → completed for any
PRD whose CUJs are all Satisfied in your review. That is the only PRD
file edit allowed in this phase — do not toggle any per-CUJ markers
(those don't exist anymore).

Return: a one-paragraph summary plus the count of CUJs per verdict
(Satisfied / Caveats / Not done) and the list of recommended priorities
for the next iteration."
```

---

## Phase 7: Compute Verdict and Update Loop State

If a prior phase already set status to `blocked` (Mocks Check pause, QA `BLOCKED`, or Phase 4 retry budget exhausted), use that status and skip the computation. Otherwise compute the verdict deterministically from **both** the QA report and PM's review — no agent call needed:

- **`done`** if QA verdict is `PASS` (or `FAIL` with LOW-only bugs) AND **every in-scope CUJ has PM verdict `Satisfied`** in `docs/pm-review.md`. Both gates must pass.
- **`continue`** otherwise — either QA found MEDIUM+ bugs (and the Phase 4 inner loop didn't already exit), or PM judged at least one CUJ `Caveats` or `Not done`. The PM review's "Recommended Next-Iteration Priorities" list seeds the next planner.

This two-key gate ensures engineering correctness (QA) and product intent (PM) both sign off before the loop terminates. QA can pass a CUJ that meets every literal acceptance criterion while PM correctly judges it `Caveats` because the impl misses the point of the feature — that's a `continue` signal, not a `done`.

Then write `docs/loop-state.md`. The `Last updated` stamp uses local time in the format `YYYY-MM-DD HH:MM:SS (UTC±N)` (e.g., `2026-05-02 14:23:45 (UTC+8)`) — day-precision is insufficient because the loop can rewrite this file multiple times per day during inner retries. Get the current timestamp via `python3 -c "from datetime import datetime as d; t=d.now().astimezone(); m=int(t.utcoffset().total_seconds()//60); s='+' if m>=0 else '-'; h,mm=divmod(abs(m),60); o=f'{h}:{mm:02d}' if mm else str(h); print(t.strftime('%Y-%m-%d %H:%M:%S')+f' (UTC{s}{o})')"`.

```markdown
# Dev Loop State

Last updated: <timestamp>
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
