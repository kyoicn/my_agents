# Global Instructions

## Code Style
- Write clear, simple code. Prefer readability over cleverness.
- Follow the conventions already established in each project.
- Don't add comments for obvious code — only explain the "why," not the "what."

## Changes
- Make minimal, focused changes. Don't refactor or "improve" surrounding code unless asked.
- Read files before editing them. Understand context before proposing changes.
- Don't add speculative features, extra error handling, or abstractions beyond what's needed.

## Communication
- Be concise. Skip preambles and summaries.
- When referencing code, include file paths and line numbers.

## Git
- Use conventional commit messages (e.g., `feat:`, `fix:`, `docs:`, `refactor:`).
- Don't push unless explicitly asked.
- Before committing, `git diff --cached --name-only` must match the commit's stated
  type/scope — a `docs:` commit carrying production code paths is a stop, not a squash.
  Prefer `git commit --only <paths>` for typed commits so staged leftovers can't ride
  along. Never `git checkout <branch> -- <paths>` into a shared checkout to inspect
  branch code (it silently stages; use the branch's worktree or `git show`).

## Workflow Discipline
- Route work by track, don't hand-edit what has a pipeline:
  feature → /design-feature · defect → /report-bug → /triage · infra/tooling/debt → /eng-task
  · graded output quality → /design-quality (calibrate the bar) → /quality-cycle (improve toward it)
- Quality is never vibe-fixed: complaints about how good generated output is triage as
  scope=quality and route to the quality track — one bad example becomes an eval case,
  not a quick-fix.
- Prefer spec-first over ad-hoc. A change to user-visible behavior goes through
  /design-feature (Route C/D) when it changes a journey's shape, /quick-fix when
  it's minimal. Ad-hoc chat edits are how specs go stale.
- Every user-visible change carries a spec-sync obligation: amend the contradicted
  PRD line and mock with the change (/quick-fix does this automatically; /spec-sync
  covers changes made outside it) — same discipline as updating tests with code.
- Document authority: user intent > PRD > design docs > tasks.md. Lower docs are
  derived views. Never silently resolve a contradiction — follow the higher
  authority and surface the conflict.
- PRDs are pure spec, never progress trackers. pm is the sole PRD writer
  (sole exception: /spec-sync's minimal, user-confirmed amendments).
- Don't bypass gates: nothing is "done" without QA's verdict; scope expansion
  escalates (/quick-fix → /dev-cycle) instead of pushing through.
- When the loop stops "blocked", the decision is yours — answer it and re-run;
  don't hand-patch around a blocker mid-cycle.

## My Preferences
<!-- Add your own instructions below -->

## Execute Tasks

When I say "execute tasks", "run tasks", "执行任务", "タスクを実行", or similar:
1. Read `docs/tasks.md` to get the task plan.
2. Execute one parallel group at a time, starting from the first pending group.
3. For each task in the group, spawn a background worktree agent — **all tasks in a group must be spawned in a single message** so they run in parallel:
   - `subagent_type: "coder"` — every task-execution agent uses the `coder` role definition (see `claude/agents/coder.md`). Coders own implementation + unit tests + local verification + commit.
   - `isolation: "worktree"` — each agent gets its own branch
   - `run_in_background: true` — non-blocking
   - The agent's prompt must be **self-contained** — include the full task description, file paths, and acceptance criteria. The agent cannot see `docs/tasks.md` or this conversation.
   - Each agent should commit its work with a conventional commit message when done.
4. As agents complete, report which succeeded (and their branch names) and which failed.
5. After a group completes, ask me before proceeding to the next group.
6. After all groups are done, ask me if I want to merge the branches.
7. Do not modify `docs/tasks.md` — that's the planner's job.
