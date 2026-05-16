---
name: "dev-cycle"
description: "Run one iteration of the autonomous development loop. Orchestrates tl, planner, task execution, qa, status, and pm agents in sequence. Updates docs/loop-state.md with iteration progress."
---

<!-- generated-from: claude/commands -->

# dev-cycle

Use this skill when the user asks to run `dev-cycle`.

## Command Template

# Dev Cycle — One Codex-Native Iteration

You are orchestrating one autonomous development iteration in Codex. Preserve the PM -> TL -> Planner -> execution -> QA -> Status -> PM review flow, but keep the main Codex session responsible for sequencing, integration, verification, and user-visible decisions.

## Setup

Check whether the user supplied a target PRD such as `dev-cycle prd-008`.

- **Scoped mode**: operate only on that specific `docs/prd/prd-008-*.md` file.
- **Unscoped mode**: operate on all active PRDs under `docs/prd/`.

Read `docs/loop-state.md` if it exists. If the previous iteration ended with QA FAIL or QA FABRICATION, this iteration must prioritize those failures before new feature work.

Read:
- `docs/prd/index.md`
- active PRDs in scope
- all files under `docs/design/`
- `docs/status.md` if present
- `docs/qa-report.md` if present
- any `docs/*-guidelines.md` files

If guideline files exist, carry their paths into every agent or worker prompt and enforce them during local implementation.

## Phase 1: Architecture Review

Use the `tl` agent when design review is useful. Ask it to review PRDs, design docs, status, and code; update `docs/design/` when design decisions are needed; and return:
- design decisions made or updated
- constraints the planner must know
- blockers requiring user input
- any quality risks from previous iterations

If there is a blocker requiring user input, update `docs/loop-state.md` with status `blocked`, report the blocker, and stop.

## Phase 2: Task Planning

Use the `planner` agent to update `docs/tasks.md`.

The planner must prioritize:
1. QA FABRICATION items, including fake data, no-op stubs, unexecuted pipelines, or claimed behavior that is not actually wired
2. QA FAIL items, including bugs and regressions
3. Highest-value unfinished CUJs in scope

Do not schedule new feature work while unresolved QA failures remain.

If the planner reports nothing left to implement and no QA failures remain, proceed to PM Review.

## Phase 3: Task Execution

Read `docs/tasks.md` and execute one parallel group at a time.

For each group:
- Delegate independent tasks to Codex worker agents only when the current workflow explicitly calls for delegated or parallel work and the tasks have disjoint file ownership.
- Give each worker a self-contained prompt with the task description, likely file paths, acceptance criteria, relevant PRDs/design docs, and guideline paths.
- Tell workers they are not alone in the codebase, must not revert others' edits, and must accommodate concurrent changes.
- Do not assume guaranteed workspace isolation, automatic branch creation, per-agent commits, or automatic branch merging.
- If delegation is not appropriate or not available, implement the group locally in the main session.

The main session owns integration. Review returned worker changes, reconcile overlaps, run formatting/type checks/tests, and make final fixes locally.

If any task fails, record the failure in `docs/loop-state.md`, continue only when it is safe, and make sure unresolved failures become follow-up tasks.

## Phase 4: Code Review

Use the `tl` agent for code review when changes are substantial. Ask it to inspect the current diff and run the relevant quality checklist:
- type safety and static checks
- architecture and framework pattern compliance
- security issues such as secrets, missing auth, or unsafe input handling
- performance issues such as unthrottled I/O or N+1 queries
- configuration issues such as hardcoded values that should be constants
- guideline compliance

The TL may fix simple, unambiguous issues. Design-level issues should be reported, not silently rewritten.

Record unresolved critical issues in `docs/loop-state.md`.

## Phase 5: QA Gate

Use the `qa` agent as the quality gate. Its verdict controls whether work is accepted.

Ask QA to:
1. Run the full relevant test suite and capture results
2. Map coverage to CUJ acceptance criteria from PRDs in scope
3. Add focused integration/E2E tests for implemented behavior when coverage is missing
4. Run tests again after adding tests
5. Manually verify user-visible flows when a dev server or app can be run
6. Check for fabrication: fake data, no-op stubs, mocked flows in production paths, unexecuted pipelines, or UI that is not connected to real behavior
7. Write `docs/qa-report.md` with per-CUJ verdicts
8. Update `docs/tasks.md` or `docs/loop-state.md` with fix tasks for every failure

If QA fails:
- update `docs/loop-state.md` with QA FAIL or QA FABRICATION
- ensure `docs/tasks.md` contains concrete fix tasks
- stop the iteration and report the gate result

Only proceed when QA passes or the user explicitly accepts the remaining risk.

## Phase 6: Status

Use the `status` agent to update `docs/status.md` from the actual code, PRDs, design docs, tasks, QA report, and recent git history.

The status update should summarize:
- implemented features and verified CUJs
- known gaps and risks
- current architecture and important technical details
- next likely work

## Phase 7: PM Review

Use the `pm` agent to review whether completed CUJs satisfy the PRDs and whether PRD statuses need updates.

Ask PM to:
- compare product requirements against implemented behavior and QA results
- mark completed CUJs only when QA evidence supports completion
- identify missing requirements, ambiguous CUJs, or product gaps
- update PRD statuses when appropriate

## Completion

Update `docs/loop-state.md` with:
- iteration number or timestamp
- scope
- phase outcomes
- completed work
- QA verdict
- blockers
- follow-up tasks

Commit with a conventional commit message only after changes are integrated and verified. Do not push unless explicitly asked.
