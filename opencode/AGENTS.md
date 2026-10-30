<!-- generated-from: claude/CLAUDE.md — do not edit; regenerate with opencode/skills/sync-from-claude -->

> **OpenCode runtime notes** — this text was written for Claude Code and adapted for OpenCode; read what remains as follows.
> - Slash commands keep their names: `/dev-cycle` is the OpenCode command `dev-cycle`, and `/loop` is the `loop` command. When the text tells *you* to run a command (for example, run `/loop /dev-cycle` when the owner says "continue"), read `~/.config/opencode/commands/<name>.md` and follow it with the arguments.
> - "Spawn a `<role>` subagent" → the `subagent` tool with `agent: "<role>"`, a short `description`, and the full prompt; `background: true` when several run at once. The roles are the `~/.config/opencode/agents/*.md` agents: tl, planner, coder, qa, reporter, pm, evaluator, researcher, gorilla. A subagent's final message is its return summary.
> - "Spawn all in a single message" → issue every `subagent` call in the same turn, then wait for all their results before going on.
> - Worktrees: OpenCode subagents share your checkout. "Own worktree `.worktrees/<branch>`" means you create it with `git worktree add .worktrees/<branch> -b <branch> HEAD` before the spawn and tell the subagent to work and commit only there; the `/dev-cycle` command's "OpenCode adaptations" section has the full recipe.
> - `question` is OpenCode's question tool. A role whose permissions deny it never asks: it returns `BLOCKER:` or files an owner-queue entry, as its text says.
> - Claude tool names left in prose (Read, Grep, Glob, Edit, Write, Bash, WebSearch, WebFetch) are OpenCode's read, grep, glob, edit, shell, websearch, and webfetch tools. MCP tools are named `<server>_<tool>`; Playwright's are `playwright_browser_*`, exposed as direct tools because `~/.config/opencode/opencode.json` runs the server with `"codemode": false`.

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
- The loop pauses at the checkpoint rungs you approved (tl's ladder in
  docs/design/system.md): look, poke, redirect, then `continue`. A pause is not
  a blocker — nothing waits in the queue except the plan review itself.
  Run-through skips those pauses, but never the stops where tl needs your
  judgment on a load-bearing decision or real samples to prove one.
- Anything waiting on your decision lives in docs/owner-queue.md — oldest on
  top; answer inline under the entry or just say it in chat (agents transcribe
  before acting). Standing rulings accumulate in docs/rulings.md; agents cite
  them by R-ID instead of re-asking.

## My Preferences
<!-- Add your own instructions below -->

## Execute Tasks

When I say "execute tasks", "run tasks", "执行任务", "タスクを実行", or similar:
1. Read `docs/tasks.md` to get the task plan.
2. Execute one parallel group at a time, starting from the first pending group.
3. For each task in the group, spawn a background worktree agent — **all tasks in a group must be spawned in a single message** so they run in parallel:
   - `agent: "coder"` — every task-execution agent uses the `coder` role definition (see `~/.config/opencode/agents/coder.md`). Coders own implementation + unit tests + local verification + commit.
   - own worktree `.worktrees/<branch>` — each agent gets its own branch
   - `background: true` — non-blocking
   - The agent's prompt must be **self-contained** — include the full task description, file paths, and acceptance criteria. The agent cannot see `docs/tasks.md` or this conversation.
   - Each agent should commit its work with a conventional commit message when done.
4. As agents complete, report which succeeded (and their branch names) and which failed.
5. After a group completes, ask me before proceeding to the next group.
6. After all groups are done, ask me if I want to merge the branches.
7. Do not modify `docs/tasks.md` — that's the planner's job.

## Continue the loop

When I say "continue", "go on", "继续", "続けて", or similar after a `/dev-cycle`
pause (status `checkpoint`): run `/loop /dev-cycle` — it iterates until the next
pause (a checkpoint rung, done, or blocked). `/dev-cycle` alone is one iteration.

When I say "run through", "no checkpoints", "build it end to end", "一口气做完",
or similar: run `/loop /dev-cycle --until done`. "Run to C4" / "stop at C4" →
`/loop /dev-cycle --until C4`.
