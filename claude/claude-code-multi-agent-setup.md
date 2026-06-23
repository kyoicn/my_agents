# Claude Code Multi-Agent Autonomous Development Setup

This document describes a complete multi-agent setup for Claude Code that enables near-autonomous development. It's the **reference manual** — architecture, design decisions, file structure, settings, prerequisites, install path. The per-agent and per-command **definitions** live in their own files under [agents/](agents/) and [commands/](commands/), linked from the tables below.

To install on a new machine, clone this repo and run [`deploy.sh`](deploy.sh) — it symlinks the agent/command files into `~/.claude/` so edits in this repo take effect immediately, no copying.

## Overview

This setup creates a team of specialized AI agents that collaborate in an autonomous development loop. The loop is driven by two slash commands: `/design-feature` runs conversational product design for new features — handling brand-new projects, new PRDs, extending existing PRDs, or refining existing CUJs — and `/dev-cycle` runs one iteration of the full execution pipeline.

**Feature development (full pipeline, autonomous):**

```
/design-feature ──► PM (conversational design of CUJ shapes AND HTML mocks
                        in lockstep — mocks saved to docs/ux/<prd-dir>/
                        during the design session; PRD references them)
                                       │
              ┌────────────────  /dev-cycle  ───────────────┐
              │                                             │
       Mocks Check (gate — pause if missing)                │
              │                                             │
       TL (architecture review)                             │
              │                                             │
       Planner (writes docs/tasks.md, severity-prioritized) │
              │                                             │
       Parallel worktree agents execute tasks               │
              │                                             │
       Merge & resolve conflicts                            │
              │                                             │
       TL (code quality review)                             │
              │                                             │
       QA (Playwright, 2-run flakiness, fabrication,        │
           visual fidelity vs mocks → docs/qa-report.md)    │
              │                                             │
        ┌─────┴─────┐                                       │
       PASS   FAIL (MEDIUM+) ─── retry (≤2×) ──► Planner ───┘
        │
       Status (report)
        │
       PM (review, mark CUJs done, update docs/prd/index.md)
        │
       Verdict (DONE / CONTINUE / BLOCKED — derived deterministically)
```

**Bug fixes (lightweight pipeline):**

```
/report-bug ──► docs/issues.md (h3 block) + docs/issues-attachments/*.png (gitignored)
       │
       ▼
   /triage  ──► appends Triage field to the issue block ──► /quick-fix  (small/medium) ──► commit
                                                      ├──► /dev-cycle  (large)
                                                      ├──► /design-feature  (spec-gap — feature needs design)
                                                      └──► ask user        (spec-conflict — report vs PRD)
```

### The agents

Each row links to the canonical agent definition. The full instructions (Core Principles, Quality Bar, Process, Interaction Style, What NOT to do) live in the linked file — this doc is no longer a duplicate.

| Agent | Role | Maintains |
|-------|------|-----------|
| [`pm`](agents/pm.md) | **Product manager + designer.** Drives feature discovery, produces CUJ shapes AND HTML mocks in lockstep during `/design-feature` sessions, writes PRDs, and reviews implemented work against intent. Held to a principal-designer quality bar (see Quality Bar section in [pm.md](agents/pm.md)). | `docs/prd/` (index + feature PRDs), `docs/ux/<prd-dir>/cuj-*.{html,...}` (mocks) |
| [`tl`](agents/tl.md) | Software architect — designs systems, makes technical decisions, produces rigorous design docs, and conducts code-quality reviews. | `docs/design/` (`system.md` + per-component design docs) |
| [`planner`](agents/planner.md) | Task decomposer — breaks work into parallelizable tasks; stateless (rewrites `docs/tasks.md` each invocation). | `docs/tasks.md` |
| [`coder`](agents/coder.md) | Implementation specialist — takes a self-contained task spec (what to do, which files, acceptance criteria) and ships it: writes the code, writes unit tests, runs the type checker, commits with a conventional commit message. Runs in its own git worktree, typically in parallel with other coders, in the background. Does not modify PRDs/design docs/task plans; does not write integration/E2E tests (qa's job); does not review its own code (tl's job). | Branch-scoped commits (no doc artifact) |
| [`qa`](agents/qa.md) | QA engineer **with gate authority**. Runs tests, drives a real browser (Playwright) and/or Android device (ADB), walks each CUJ twice for flakiness detection, identifies fabrications, compares against mocks under `docs/ux/`, rolls back tasks that fail verification. | `docs/qa-report.md` |
| [`status`](agents/status.md) | Status reporter — summarizes current project state. | `docs/status.md` |
| [`gorilla`](agents/gorilla.md) | Adversarial exploratory tester — black-box destructive testing of the running product. No CUJ/spec context during attack; walks a 9-category attack taxonomy (input fuzzing, state corruption, races, navigation chaos, storage tampering, viewport extremes, network failure, auth probing, accessibility). Files every reproducible finding as an h3 block in `docs/issues.md`. | `docs/gorilla/<session-id>/report.md` (per-session) + `docs/gorilla/<session-id>/screenshots/` (gitignored) |

### The slash commands

Each row links to the canonical command definition.

| Command | Purpose |
|---------|---------|
| [`/design-feature`](commands/design-feature.md) | Design a product feature conversationally. Routes to one of four outcomes (Route A bootstrap brand-new project / Route B new PRD in existing project / Route C extend existing PRD with new CUJs / Route D refine existing CUJs in place). **CUJ shapes AND HTML mocks are produced together** during the design conversation; mocks save under `docs/ux/<prd-dir>/`; file paths included in every response so the user can `open` them. |
| [`/dev-cycle`](commands/dev-cycle.md) | One iteration of the autonomous loop. Phases: Mocks Check → Architecture Review → Task Planning → Parallel Execution → Merge → Code Review → QA Gate → Status → PM Review → Verdict. Use with `/loop /dev-cycle` for continuous operation. |
| [`/report-bug`](commands/report-bug.md) | Conversational bug intake with screenshot support (clipboard via `pngpaste` → file path → interactive `screencapture` → skip). Writes an h3 block to `docs/issues.md`; screenshots to `docs/issues-attachments/` (gitignored). Optionally chains into `/triage`. |
| [`/triage`](commands/triage.md) | Diagnose issues. Reads issue blocks from `docs/issues.md` (also accepts an issue ID or freeform description). Appends a structured `Triage` field — scope, root cause, files, recommended action, risk. |
| [`/quick-fix`](commands/quick-fix.md) | Fast-path fix for small/medium-scope issues. Operates on a `docs/issues.md` block by ID or on an ad-hoc description. Escalates if scope expands mid-fix. |
| [`/gorilla-test`](commands/gorilla-test.md) | Manual-only adversarial exploratory test session against the running product. `--time <30m\|1h\|...>` (default 30m, max 4h), optional `--path </articles>`. Files every finding to `docs/issues.md`; per-session output in `docs/gorilla/<session-id>/`. |
| [`/organize-project`](commands/organize-project.md) | One-time-per-project skill to retrofit an existing project into the canonical pattern. Audits scattered docs broadly, reconciles per-doc with user (migrate/adopt/preserve/ignore), scaffolds missing infrastructure, derives design docs from code, backfills PRDs that describe what's actually built. **Idempotent**. |
| [`/worktree-start`](commands/worktree-start.md) | Spin up a parallel Claude session: create a new git worktree at `../<repo>-<slug>` on branch `feature/<slug>`, open it in a new Antigravity window. Lets you work on UI, data, mocks, etc. simultaneously without disturbing the current window. |
| [`/worktree-finish`](commands/worktree-finish.md) | Finish a feature worktree (run from inside it): verify clean state, merge the feature branch into `main` with a regular `--no-ff` merge commit, remove the worktree, delete the branch. **Local-only** — no push, no PR. |
| [`/worktree-sync`](commands/worktree-sync.md) | Mid-feature two-way sync between a feature worktree and `main` (run from inside the worktree): push the feature's committed work onto `main` so other worktrees can pick it up, then pull `main`'s updates back into this worktree. Worktree stays alive. **Local-only**. |

### The workflows

**Design a feature (works for brand-new project, new PRD, extension, or refinement):**
```
/design-feature "<freeform pitch>"  → conversational discovery in the main thread;
                                      orchestrator decides route (A/B/C/D) and
                                      confirms with user; same agent produces CUJ
                                      shapes AND HTML mocks in lockstep, saving
                                      mocks to docs/ux/<prd-dir>/ during the session;
                                      pm subagent then writes/extends/refines the
                                      PRD referencing the saved mocks; docs/status.md
                                      is updated route-aware.
```
During the session, the agent saves each mock to disk and includes the absolute file path in its response. You open the file in your browser (`open <path>` on macOS) to see what was drawn; refresh on each revision. No external designer involved — everything happens in the one `/design-feature` conversation.

**Feature development (autonomous):**
```
/design-feature "<pitch>"           # design the feature + draw mocks together
/loop /dev-cycle                    # runs the full loop autonomously until done or blocked
```

**Feature development (manual pipeline):**
```
/user:pm "define the feature"       → writes docs/prd/prd-NNN-<slug>.md
/user:tl                            → writes docs/design/
/user:planner                       → writes docs/tasks.md
"execute tasks"                     → main agent spawns parallel coder subagents in worktrees
/user:tl (code review)              → reviews code quality, fixes simple issues
/user:qa                            → writes docs/qa-report.md
```

**Bug fixes:**
```
/report-bug "<description>"         # conversational intake — handles screenshots,
                                    # writes h3 block to docs/issues.md, optionally
                                    # chains into /triage
/triage <issue-id|description>      # diagnose: scope, root cause, recommended action
/quick-fix <issue-id|description>   # fast-path fix for small/medium-scope, then
                                    # removes the block + its screenshots
```

The three-stage pipeline (`report → triage → fix-or-escalate`) is well-factored: each step is independently invocable, and `/report-bug` chains into `/triage` on user opt-in for the common all-in-one flow.

**Parallel sessions across worktrees:**

When you want to drive multiple concerns in parallel — UI in one window, data pipelines in another, mocks in a third — without the windows fighting over files or branches, use the worktree commands. Each `/worktree-start` opens a new Antigravity window with its own Claude session, on its own branch.

```
/worktree-start ui                  # new worktree at ../<repo>-ui, branch feature/ui;
                                    # opens in a new Antigravity window
/worktree-start data                # repeat for each concern
/worktree-start mocks
```

Mid-feature, when two worktrees need to share an update (e.g., a shared design doc both are editing), the writer-side worktree runs:

```
/worktree-sync                      # push your committed work onto main, then
                                    # pull main's updates back into your worktree
```

Each other worktree picks up the new main on their next `/worktree-sync`. When a worktree's work is done:

```
/worktree-finish                    # merge feature into main with --no-ff,
                                    # remove the worktree, delete the branch
                                    # (close the now-stale Antigravity window)
```

All three skills are local-only — no remote pushes, no PRs. You control when to `git push main` after merges land.

### Key design decisions

1. **Worktree isolation at two layers**: (a) Implementation subagents run in git worktrees during `/dev-cycle` Phase 3 — each gets its own branch and working directory, enabling true parallel development with no conflicts. (b) The user can also spin up parallel top-level Claude sessions across worktrees via `/worktree-start` — each editor window drives its own concern (UI, data, mocks, etc.) on its own branch without disturbing the others. Same git mechanism, different layer.
2. **The main agent is the orchestrator**: Task execution happens in the main session (not a subagent) so the user sees real-time progress and can keep interacting. This is why "execute tasks" is a CLAUDE.md instruction, not a custom agent.
3. **Stateless planner**: The planner derives tasks fresh every invocation from PRDs + design docs + status + code. `docs/tasks.md` is always overwritten, never accumulated. This prevents stale task drift.
4. **Working language detection**: All agents detect the project's working language from existing `docs/` files and write in that language. Technical terms are preserved as-is.
5. **PRDs organized by feature, design docs organized by engineering domain**: PM writes CUJ-driven PRDs per product feature. TL writes design docs per engineering component/subsystem. Multiple PRDs may feed into one design doc; one PRD may require updates to multiple design docs. This decoupling prevents artificial 1:1 constraints.
6. **Design docs as one coherent body**: All files in `docs/design/` form a single comprehensive engineering design document — individual files are chapters. `system.md` covers cross-cutting concerns; `design-<slug>.md` files cover component-specific design. The TL always reads ALL design docs before making changes to maintain consistency.
7. **Separate pipelines for features vs. bugs**: Feature work flows through the full PM → TL → Planner → Execute → QA pipeline via `/design-feature` + `/dev-cycle`. Bug fixes use a lightweight `/report-bug` → `/triage` → `/quick-fix` path that bypasses PRDs and design docs (the spec isn't wrong, the code is). Large bugs that reveal design flaws are escalated to `/dev-cycle`; bugs that reveal *spec* flaws are escalated to `/design-feature` (Route C or D).
8. **Issues inbox, not issue tracker**: `docs/issues.md` is a write-only intake queue — anyone can jot down a problem. Triage diagnoses entries and routes them. Resolved entries are removed. History lives in git log, not in the inbox.
9. **QA as a gate, not a reporter**: `qa` has the authority to roll back `[x]` tasks that fail verification, append fix tasks for each bug, and enforce the loop's retry rules. Gate behavior is mechanical (see Step 9 of the QA agent).
10. **Orthogonal QA dimensions**: Every QA finding has a Result (PASS/FAIL/BLOCKED/NOT_RUN/WAIVED), Coverage (automated/manual/both/none), and Bug attributes (Severity × Kind). Severity drives the loop's retry decisions; Kind is descriptive.
11. **Two-run flakiness detection**: QA walks every CUJ twice with a fresh browser session. Inconsistent results between the runs are logged as `[FLAKY]` and treated pessimistically as FAIL — catching the failures that hide on a single pass.
12. **Visual fidelity via mocks under `docs/ux/`**: Mocks live at `docs/ux/<prd-dir>/cuj-<id>-<state>.<ext>`. QA discovers them by glob, compares to the running product side-by-side, and logs `[VISUAL_DEVIATION]` findings by severity. Missing mocks → log `NO_MOCK`, continue without blocking.
13. **Mocks produced during design, not as an async handoff**: The same `pm` agent that drives `/design-feature`'s discovery and CUJ-shape iteration also produces the HTML mocks — synchronously, in lockstep with shape iteration. Mocks save to `docs/ux/<prd-dir>/cuj-<id>-<state>.html`. The dev-cycle's Mocks Check is a fallback for CUJs that never went through `/design-feature` (e.g., backfilled by `/organize-project`); when found, it points the user to `/design-feature` Route D to add the mocks.
14. **Deterministic verdict**: `/dev-cycle`'s final phase derives DONE/CONTINUE/BLOCKED mechanically from the QA verdict + remaining `[ ]` CUJs after PM review. No additional agent call needed.
15. **Four-way role split: design / decompose / implement / verify**: `tl` designs (read code → propose architecture → maintain `docs/design/`); `planner` decomposes (read PRDs + design + status → propose tasks → write `docs/tasks.md`); `coder` implements (read task → write code + unit tests → commit); `qa` verifies (read PRDs + code + running product → write integration/E2E tests → produce `docs/qa-report.md` with gate authority). No role does another's work. tl doesn't write feature code; planner doesn't pick the architecture; coder doesn't write E2E tests; qa doesn't write unit tests. Each role's "What NOT to do" list enforces the boundary, so the orchestrator has clear delegation rules and any new requirement routes to exactly one owner.

---

## File Structure

```
~/.claude/
├── CLAUDE.md                       # Global instructions for the main agent
├── settings.json                   # Permissions and model preferences
├── agents/
│   ├── pm.md                       # Product manager agent
│   ├── tl.md                       # Tech lead / architect agent
│   ├── planner.md                  # Task decomposition agent
│   ├── coder.md                    # Implementation agent (writes code + unit tests; runs in a worktree)
│   ├── qa.md                       # QA / testing agent (spec-driven verification)
│   ├── status.md                   # Status reporter agent
│   └── gorilla.md                  # Adversarial exploratory test agent (black-box destructive)
└── commands/
    ├── design-feature.md           # Design a feature (bootstrap / new PRD / extend / refine)
    ├── dev-cycle.md                # Autonomous loop command (one iteration)
    ├── report-bug.md               # Conversational bug intake with screenshot support
    ├── triage.md                   # Issue diagnosis and scope assessment
    ├── quick-fix.md                # Small-scope bug fix
    ├── gorilla-test.md             # Manual adversarial exploratory test session
    ├── organize-project.md         # Retrofit an existing project into the canonical pattern (one-time-per-project)
    ├── worktree-start.md           # Spin up a parallel session: new worktree + branch + Antigravity window
    ├── worktree-finish.md          # Finish a feature worktree: merge into main, remove, delete branch (local-only)
    └── worktree-sync.md            # Mid-feature two-way sync between a feature worktree and main (local-only)
```

Generated by the loop in any project that uses this setup:

```
<project-dir>/
└── docs/
    ├── prd/
    │   ├── index.md                # PRD master list, vision, personas
    │   └── prd-NNN-<slug>.md       # one per feature
    ├── design/
    │   ├── system.md               # cross-cutting design (canonical name)
    │   └── design-<slug>.md        # per engineering component
    ├── ux/
    │   └── prd-NNN-<slug>-mockups/
    │       └── cuj-<id>-<state>.html  # mocks produced by pm during /design-feature
    ├── tasks.md                    # planner output; overwritten each cycle
    ├── status.md                   # status agent output
    ├── qa-report.md                # QA agent output
    ├── qa-artifacts/<run-id>/<cuj-id>/run{1,2}/    # <run-id> = iter<N>-<HH-MM-SS>
    │   └── *.png                   # screenshots from the QA walks
    ├── loop-state.md               # iteration counter + last verdict
    ├── issues.md                   # bug intake (h3-block format, written by /report-bug and gorilla)
    ├── issues-attachments/         # bug screenshots — gitignored, deleted on /quick-fix
    │   └── <issue-id>-<N>.png      # one per attached screenshot
    ├── gorilla/                    # per-session gorilla output (chronological history)
    │   └── <session-id>/
    │       ├── report.md           # this session's summary (committed)
    │       └── screenshots/        # this session's screenshots — gitignored
    │           └── <NN>-<slug>.png
    └── *-guidelines.md             # optional mandatory rules picked up each cycle
```

---

## 1. Settings: `~/.claude/settings.json`

Pre-approve common tools so agents don't prompt for every command, and set the default model and theme.

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(ls *)",
      "Bash(npm *)",
      "Bash(npx *)",
      "Bash(node *)",
      "Bash(curl *)",
      "Bash(python *)",
      "Bash(python3 *)",
      "Bash(awk *)",
      "Bash(echo *)",
      "Bash(./scripts/qa-server.sh *)",
      "Bash(./scripts/qa-server.sh)",
      "Bash(chmod +x scripts/qa-server.sh)",
      "Bash(./scripts/qa-android.sh *)",
      "Bash(./scripts/qa-android.sh)",
      "Bash(chmod +x scripts/qa-android.sh)",
      "Read",
      "Edit",
      "Write",
      "Glob",
      "Grep",
      "WebSearch",
      "WebFetch",
      "mcp__playwright__*"
    ]
  },
  "effortLevel": "high",
  "theme": "dark-daltonized",
  "model": "claude-opus-4-7"
}
```

Add more `Bash(<prefix> *)` entries as needed for your stack (e.g., `Bash(swift *)`, `Bash(bun *)`, `Bash(cargo *)`).

---

## 2. Global Instructions: `~/.claude/CLAUDE.md`

These are project-agnostic instructions for the main agent. Merge with any existing CLAUDE.md content — don't overwrite.

````markdown
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

## My Preferences
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
````

---

## Prerequisites

QA needs real tooling per target type. Install what applies:

### Web targets — Playwright MCP

```
claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest
```

Without it, QA cannot drive a browser and will set affected CUJs to `BLOCKED` rather than fabricate a verdict. The first time QA navigates, it will auto-install the browser binaries.

### Native Android targets — Android SDK platform-tools + (optional) emulator

On macOS:

```
brew install --cask android-platform-tools
```

Or via the Android SDK Manager / Android Studio. Verify:

```
adb version
adb devices    # should show a connected device or running emulator
```

For autonomous emulator boot, also install the Android emulator package and create an AVD (via `avdmanager` or Android Studio). Tell QA the AVD name by editing `EMULATOR_NAME` in the generated `scripts/qa-android.sh` after first run. Without an AVD configured AND without a physical device connected, QA will set affected Android CUJs to `BLOCKED`.

### Other targets (iOS, etc.)

Not supported in this setup yet. QA will set affected CUJs to `BLOCKED` for unsupported targets — never fabricates verification.

---

## Setup Instructions

To set up on a new machine:

1. **Clone this repo** (the one containing this doc) somewhere on disk.
2. **Run `./deploy.sh`** from the repo root. The script symlinks `claude/agents/`, `claude/commands/`, `claude/CLAUDE.md`, and `claude/settings.json` into `~/.claude/` so edits in the repo take effect immediately — no copy step required.
3. **Install the Playwright MCP** per the Prerequisites section above (and the Android SDK platform-tools if you'll be testing Android targets).
4. **Optional**: merge any pre-existing `~/.claude/CLAUDE.md` content with the repo's version (the deploy script will overwrite the symlink target; preserve any other instructions you had).

If you'd rather not symlink and want a static copy, just `cp -r claude/agents claude/commands claude/CLAUDE.md claude/settings.json ~/.claude/`. Trade-off: edits to the repo no longer flow into `~/.claude/` automatically.

### Bootstrap without the repo

If you don't have this repo cloned but want to recreate the setup from scratch, the source of truth for every agent and command lives at the linked files in the [agents/](agents/) and [commands/](commands/) tables above. Read each linked file and copy its content to the corresponding path under `~/.claude/`. The settings and CLAUDE.md content are inlined in Sections 1 and 2 of this doc respectively.

Then verify with:
- `/user:pm` — should respond as PM
- `/user:tl` — should respond as architect
- `/user:planner` — should respond as planner
- `/user:coder` — should respond as implementation specialist (writes code + unit tests; refuses to modify PRDs / design / tasks)
- `/user:qa` — should respond as QA
- `/user:status` — should generate status report
- `/user:gorilla` — should respond as the gorilla testing agent (refuses to read PRDs/code before attacking)
- `execute tasks` — main agent should read docs/tasks.md and spawn worktree agents with `subagent_type: "coder"`
- `/design-feature "test pitch"` — should detect context (brand-new vs existing project), drive conversational discovery in the main thread, and route to bootstrap / new PRD / extend / refine
- `/dev-cycle` — should run one full autonomous iteration
- `/report-bug "test bug"` — should drive conversational intake, attempt screenshot capture (prompts you through the options), write an h3 block to `docs/issues.md`, and ensure `docs/issues-attachments/` is in `.gitignore`
- `/triage` (or `/triage <issue-id>`) — should diagnose open issue blocks and append a `Triage` field to each
- `/quick-fix <issue-id>` — should fix the issue and remove the block + its referenced screenshots
- `/gorilla-test --time 5m` — should set up a session, ensure the dev server is up, spawn the gorilla, and file any reproducible findings to `docs/issues.md` (use a tiny budget to spot-check the wiring; for a real session use 30m+)
- `/organize-project` — in a project that has working code but no `docs/prd/`, should audit existing markdown broadly, propose how to reconcile non-canonical docs, scaffold infrastructure, and backfill PRDs + design docs from the code. Idempotent — re-running on an already-organized project should be a near-noop
- `/worktree-start test-parallel` — should create `../<repo>-test-parallel` on a new `feature/test-parallel` branch and open it in a new Antigravity window
- `/worktree-sync` (from inside that worktree, after committing something) — should two-way merge with main and leave the worktree intact
- `/worktree-finish` (from inside that worktree, when done) — should merge into main with `--no-ff`, remove the worktree, delete the branch
- `/loop /dev-cycle` — should run autonomous iterations until done or blocked
