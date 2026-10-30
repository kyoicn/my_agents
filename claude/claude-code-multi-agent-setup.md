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
       TL (architecture review + checkpoint ladder)         │
              │                                             │
       Checkpoint Plan Review (first cycle after a PRD      │
         change: owner approves where the loop will pause)  │
              │                                             │
       Planner (writes docs/tasks.md, severity-prioritized, │
                bounded by the active checkpoint rung)      │
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
       Reporter (report)
        │
       PM (review, mark CUJs done, update docs/prd/index.md)
        │
       Verdict (DONE / CONTINUE / BLOCKED / CHECKPOINT — derived deterministically;
                CHECKPOINT = a rung reached: owner looks, pokes, says `continue`)
```

**Bug fixes (lightweight pipeline):**

```
/report-bug ──► docs/issues.md (h3 block) + docs/issues-attachments/*.png (gitignored)
       │
       ▼
   /triage  ──► diagnoses each issue, writes its Triage field (incl. Route), hands it off:
       │
       ├─ run now ──► /quick-fix       (small/medium) ──► commit
       │          ├─► /spec-sync       (spec-stale — code is right, doc is stale)
       │          ├─► /design-feature  (spec-gap — feature needs design)
       │          └─► ask user         (spec-conflict — report vs PRD; headless → R-NNN in docs/owner-queue.md)
       ├─ queued ───► /dev-cycle       (large — its next run takes it; closed once QA confirms the fix)
       │          ├─► /quality-cycle   (quality — its next run hands the example to the evaluator)
       │          └─► /design-quality  (quality, no bar yet — the session calibrates on the example)
       └─ moved ────► docs/eng-backlog.md  (misfiled eng task, or debt found during diagnosis)
```

**Engineering tasks (backlog pipeline):**

```
/eng-task ──► docs/eng-backlog.md (h3 block: Background, Scope, Acceptance criteria,
      │        mandatory executable Verify, Priority, optional Ordering/Relates-to;
      │        tl also files entries here during architecture review)
      │
      ├──► planner (first-class input: blocking > CUJs; P1 interleaved with CUJs;
      │             P2 as capacity allows) ──► coder worktrees ──► tl review confirms
      │             Verify evidence and removes completed blocks
      │
      └──► /quick-fix ENG-NNN  (fast path: small scope AND no Ordering constraint)
```

**Graded quality (spec–measure–improve pipeline):**

```
/design-quality ──► PM + user calibrate the bar (your judgments on real
                        candidate outputs → anchored scales + hard constraints;
                        ~30–50-item labeling session; pm writes
                        docs/quality/<slug>/qspec.md; evaluator builds +
                        calibrates the judge against your labels, seeds the
                        dev/holdout eval set → validated instrument or BLOCKED)
                                       │
              ┌────────────  /quality-cycle <slug>  ─────────────┐
              │                                                  │
       Instrument check (gate — no measurement, no loop)         │
              │                                                  │
       Evaluator (official baseline run on the dev set)          │
              │                                                  │
       Researcher (diagnose top failure category → design ONE    │
                   experiment, prediction stated before the run) │
              │                                                  │
       Coder (implements in a worktree, branch exp/<EXP-id>)     │
              │                                                  │
       Eval-asset guard (strips branch edits to docs/quality,    │
                  docs/prd, owner files — before any scoring)    │
              │                                                  │
       Evaluator (scores in the worktree — delta vs baseline     │
                  vs noise floor → ACCEPTED merge / REJECTED     │
                  discard)                                       │
              │                                                  │
       Researcher (lab-notebook entry — negative results kept)   │
              │                                                  │
        ┌─────┴─────┐                                            │
   dev bar met   budget remaining ─── next iteration ────────────┘
        │
       Evaluator (holdout gate run — thresholds must hold there)
        │
       Verdict (thresholds-met / plateau → decision menu filed as R-NNN /
               budget-exhausted / blocked) + your 2-minute spot-check
               (filed as a queue stub — contents stay message-only)
```

**Owner decisions (cross-track rail):**

```
   mid-phase, shared-checkout roles           at the loop boundary, orchestrators
   tl · planner · qa · evaluator ·            dev-cycle / quality-cycle / design-* / triage:
   researcher · pm — file directly,           BLOCKER returns (coder's only path — worktree
   cite R-NNN in their own outputs            writes die with branches) · blocked states ·
   (non-blocking decisions)                   register-then-ask · session-yield leftovers ·
              │                               plateau menus · spot-check stubs (existence
              │                               only; contents stay message-only)
              │                                                │
              └───────────────────┬────────────────────────────┘
                                  ▼
        ┌──────────────────────────────────────────────────────────┐
        │        docs/owner-queue.md — human-first, drained        │
        │  admission gate: a pipeline is blocked-or-wrong without  │
        │  the answer AND no lower authority decides it · rows     │
        │  are pointers to the item's home track · no FYIs ·       │
        │  oldest on top · explicit empty state                    │
        └──────────────────────────────────────────────────────────┘
           │                         │                         │
           │ owner: answer slot,     │ Setup sweep (dev-cycle  │ read-only views:
           │ chat (transcribed       │ + quality-cycle, every  │ status.md pointer
           │ before acting),         │ iteration): armed       │ + count · every
           │ park, or delete         │ defaults · answer       │ exit report line
           │ (= decline, default     │ slots · owner-lint      │ "+n filed / m
           │ applies)                │ (red auto-remediated,   │ closed / j open
           │                         │ yellow → exit line)     │ (oldest R-NNN)"
           └───────────┬─────────────┘
                       ▼
        close-time classification:
        "does this govern cases nobody has looked at yet?"
                       │
             ┌─────────┴─────────┐
             ▼                   ▼
       no — transient        yes — durable
       entry DELETED         entry MOVED to docs/rulings.md
       (outcome recorded     (append-only, agent-facing registry;
       by the acting track;  Scope-tagged · consumers: judge/linter
       history in git log)   errata cite their ruling · quality-cycle
                             reads standing authorizations · class
                             rulings govern future cases)
```

### The agents

Each row links to the canonical agent definition. The full instructions (Core Principles, Quality Bar, Process, Interaction Style, What NOT to do) live in the linked file — this doc is no longer a duplicate.

| Agent | Role | Maintains |
|-------|------|-----------|
| [`pm`](agents/pm.md) | **Product manager + designer.** Drives feature discovery, produces CUJ shapes AND HTML mocks in lockstep during `/design-feature` sessions, writes PRDs, and reviews implemented work against intent. Held to a principal-designer quality bar (see Quality Bar section in [pm.md](agents/pm.md)). | `docs/prd/` (index + feature PRDs), `docs/ux/<prd-dir>/cuj-*.{html,...}` (mocks) |
| [`tl`](agents/tl.md) | Software architect — designs systems, makes technical decisions, produces rigorous design docs, authors the checkpoint ladder (where the loop pauses for the owner), and conducts code-quality reviews. | `docs/design/` (`system.md` incl. Build Order & Checkpoints + per-component design docs) |
| [`planner`](agents/planner.md) | Task decomposer — breaks work into parallelizable tasks; stateless (rewrites `docs/tasks.md` each invocation). | `docs/tasks.md` |
| [`coder`](agents/coder.md) | Implementation specialist — takes a self-contained task spec (what to do, which files, acceptance criteria) and ships it: writes the code, writes unit tests, runs the type checker, commits with a conventional commit message. Runs in its own git worktree, typically in parallel with other coders, in the background. Does not modify PRDs/design docs/task plans; does not write integration/E2E tests (qa's job); does not review its own code (tl's job). | Branch-scoped commits (no doc artifact) |
| [`qa`](agents/qa.md) | QA engineer **with gate authority**. Runs tests, drives a real browser (Playwright) and/or Android device (ADB), walks each CUJ twice for flakiness detection, identifies fabrications, compares against mocks under `docs/ux/`, and issues the binding gate verdict. | `docs/qa-report.md` |
| [`reporter`](agents/reporter.md) | Project reporter — sole owner of the human-facing view; derives state from the sources of truth, never decides. Carries the owner-queue pointer line. (Renamed from `status` — the agent name now matches the role, not the artifact.) | `docs/status.md` |
| [`gorilla`](agents/gorilla.md) | Adversarial exploratory tester — black-box destructive testing of the running product. No CUJ/spec context during attack; walks a 9-category attack taxonomy (input fuzzing, state corruption, races, navigation chaos, storage tampering, viewport extremes, network failure, auth probing, accessibility). Files every reproducible finding as an h3 block in `docs/issues.md`. | `docs/gorilla/<session-id>/report.md` (per-session) + `docs/gorilla/<session-id>/screenshots/` (gitignored) |
| [`evaluator`](agents/evaluator.md) | **Measurement institution with gate authority** for graded quality. Owns eval sets (dev/holdout custody), the judge + its calibration gate (no agreement with the user's labels → no verdicts), the noise floor (within-noise deltas are inconclusive, never improvements), official runs + budget ledger, and the descriptive-only failure taxonomy. Never diagnoses causes or touches implementation. | `docs/quality/<slug>/`: `eval-report.md`, `evalset/`, `judge/`, `ledger.md` |
| [`researcher`](agents/researcher.md) | Empirical quality scientist — diagnoses failure mechanisms from the evaluator's taxonomy + traces + code, designs ranked falsifiable experiments (prediction stated before the run) for coder to implement. Judges hypotheses (confirmed/refuted); never changes (that's the evaluator's gate). Cannot touch eval sets, judge, or qspec. | `docs/quality/<slug>/experiments.md` (append-only lab notebook) |

### The slash commands

Each row links to the canonical command definition.

| Command | Purpose |
|---------|---------|
| [`/design-feature`](commands/design-feature.md) | Design a product feature conversationally. Routes to one of four outcomes (Route A bootstrap brand-new project / Route B new PRD in existing project / Route C extend existing PRD with new CUJs / Route D refine existing CUJs in place). **CUJ shapes AND HTML mocks are produced together** during the design conversation; mocks save under `docs/ux/<prd-dir>/`; file paths included in every response so the user can `open` them. |
| [`/dev-cycle`](commands/dev-cycle.md) | One iteration of the autonomous loop. Phases: Mocks Check → Architecture Review → Checkpoint Plan Review (first cycle after a PRD change, or when a load-bearing decision is new, changed, or reopened: the owner approves the design and where the loop will pause) → Task Planning → Checkpoint A (commit) → Parallel Execution → Merge → Code Review → QA Gate → Status → PM Review → Verdict (`done` / `continue` / `blocked` / `checkpoint`) → Checkpoint B (commit). `/loop /dev-cycle` runs to the next pause; `--until done` runs through, `--until Cn` pauses at a named rung. |
| [`/report-bug`](commands/report-bug.md) | Conversational bug intake with screenshot support (clipboard via `pngpaste` → file path → interactive `screencapture` → skip). Writes an h3 block to `docs/issues.md`; screenshots to `docs/issues-attachments/` (gitignored). Optionally chains into `/triage`. |
| [`/triage`](commands/triage.md) | Diagnose and route issues. Reads issue blocks from `docs/issues.md` (also accepts an issue ID or freeform description). Appends a structured `Triage` field — scope, root cause, files, route, risk — then hands each issue off: run-now routes (`/quick-fix`, `/spec-sync`, `/design-feature`, the spec-conflict question) execute in the session; queued routes (`/dev-cycle`, `/quality-cycle`, `/design-quality`) are taken by that command's next run. |
| [`/quick-fix`](commands/quick-fix.md) | Fast-path fix for small/medium-scope work items. Operates on a `docs/issues.md` block by ID, an ad-hoc description, or a small `docs/eng-backlog.md` entry (`/quick-fix ENG-NNN` — left for the planner if the entry has an Ordering constraint). Anything not small/medium — at intake or mid-fix — is routed per `/triage`'s table, never refused. Runs the spec-sync check after every fix (Step 6). |
| [`/spec-sync`](commands/spec-sync.md) | Reconcile PRDs/mocks with intentional out-of-band changes — minimal, user-confirmed, docs-only amendments to the exact contradicted lines. Scoped by construction (description / CUJ / commit range / recent delta); `--all` is an inventory-first sweep of statically-checkable assertions with per-CUJ commits. The sole exception to pm's PRD ownership. |
| [`/eng-task`](commands/eng-task.md) | Conversational intake for engineering tasks (infrastructure, tooling, operational hardening, tech debt) — the third track alongside defects and features. Writes an h3 block to `docs/eng-backlog.md` with a **mandatory mechanically executable `Verify` check** (no Verify → no entry), Priority (`blocking`/`P1`/`P2`), and optional Ordering constraints. Owns the canonical classification rule for the three tracks. Offers the `/quick-fix ENG-NNN` fast path for small, unconstrained entries. |
| [`/gorilla-test`](commands/gorilla-test.md) | Manual-only adversarial exploratory test session against the running product. `--time <30m\|1h\|...>` (default 30m, max 4h), optional `--path </articles>`. Files every finding to `docs/issues.md`; per-session output in `docs/gorilla/<session-id>/`. |
| [`/organize-project`](commands/organize-project.md) | One-time-per-project skill to retrofit an existing project into the canonical pattern. Audits scattered docs broadly, reconciles per-doc with user (migrate/adopt/preserve/ignore), scaffolds missing infrastructure, derives design docs from code, backfills PRDs that describe what's actually built. **Idempotent**. |
| [`/design-quality`](commands/design-quality.md) | Calibrate a quality bar for a quality-bearing feature (summarization, ranking, extraction, pipelines). Shape detection (absolute-graded / comparative / ground-truth / proxy) → your judgments on contrasting candidate outputs become anchored scales → labeling session (~30–50 items) → pm writes `docs/quality/<slug>/qspec.md` → evaluator builds + calibrates the judge and seeds the eval set. Ends with a validated instrument or an honest BLOCKED. |
| [`/quality-cycle`](commands/quality-cycle.md) | Autonomous quality improvement for one surface (`quality-cycle <slug>`): instrument check → baseline → researcher designs one experiment → coder implements in a worktree → evaluator scores + gates → lab-notebook entry — iterating within the qspec's eval budget. Verdicts: `thresholds-met` (holdout-confirmed), `plateau` (a decision menu for you), `budget-exhausted`, `blocked`. Eval-asset merge guard; probe code graduates via eng-backlog + tl, never merges. |
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
/loop /dev-cycle                    # first stop: the checkpoint plan review (approve where
                                    # the loop pauses for you); then runs to the next pause —
                                    # a checkpoint rung, done, or blocked
continue                            # (in chat) run to the next pause
/loop /dev-cycle --until done       # run through overnight; --until C4 pauses at that rung
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
/triage <issue-id|description>      # diagnose, then route: small fixes run now
                                    # via /quick-fix; large/quality are queued
                                    # for the loop that owns them
/quick-fix <issue-id|description>   # fast-path fix for small/medium-scope, then
                                    # removes the block + its screenshots
```

The three-stage pipeline (`report → triage → routed fix`) is well-factored: each step is independently invocable, and `/report-bug` chains into `/triage` on user opt-in for the common all-in-one flow.

**Engineering tasks:**
```
/eng-task "<description>"           # conversational intake — classification check,
                                    # Background/Scope/Acceptance criteria, mandatory
                                    # executable Verify, Priority, optional Ordering;
                                    # writes h3 block to docs/eng-backlog.md
/quick-fix ENG-NNN                  # fast path for small, unconstrained entries
/dev-cycle                          # everything else: planner schedules entries
                                    # against CUJs and bugs; coder executes; tl
                                    # confirms Verify evidence and closes the entry
```

Which track does work belong to? **Does the product deviate from its spec for a user today?** → defect (`/report-bug`). **Does it change what the product does for users** (product surface, needs design)? → feature (`/design-feature`). **Everything else that changes code, infra, tooling, or process** → engineering task (`/eng-task`). Hybrids split at the boundary: a defect whose fix reveals tech debt keeps the fix as the defect and files the debt as a linked ENG entry; a feature with infra prerequisites gets ENG entries linked from the PRD, scheduled ahead of it. (`/eng-task` holds the canonical version of this rule; `/triage` applies it to reroute misfiled reports.)

**Graded quality:**
```
/design-quality "<surface>"         # calibrate the bar conversationally —
                                    # your judgments on real candidate
                                    # outputs become the qspec's anchors;
                                    # evaluator builds + calibrates the judge
/quality-cycle <slug>               # autonomous improvement toward the bar:
                                    # measure → diagnose → one experiment →
                                    # score → gate, within the eval budget
```

Route here whenever the complaint is about *how good* generated output is rather than whether the feature works — one bad summary from a correctly-running pipeline is an eval-case candidate, not a bug (`/triage` classifies these as scope=`quality`). No qspec yet → `/design-quality` comes first; `/quality-cycle` refuses to run without a calibrated instrument.

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

1. **Worktree isolation at two layers**: (a) Implementation subagents run in git worktrees during `/dev-cycle` Phase 3 — each gets its own branch and working directory, enabling true parallel development with no conflicts. A worktree branches from the last commit, so anything uncommitted is invisible to it — which is why the orchestrator commits at two fixed checkpoints: before every Phase 3 spawn (pending spec + the plan, plus qa's tests on retry passes) and at every stop (the iteration record; `loop-state.md`'s last commit doubles as the cycle-boundary marker). Subagents in the shared checkout don't commit; `/design-feature` and `/design-quality` commit their own outputs, and `/quality-cycle` checkpoints the same way around its experiment worktrees. (b) The user can also spin up parallel top-level Claude sessions across worktrees via `/worktree-start` — each editor window drives its own concern (UI, data, mocks, etc.) on its own branch without disturbing the others. Same git mechanism, different layer.
2. **The main agent is the orchestrator**: Task execution happens in the main session (not a subagent) so the user sees real-time progress and can keep interacting. This is why "execute tasks" is a CLAUDE.md instruction, not a custom agent.
3. **Stateless planner**: The planner derives tasks fresh every invocation from PRDs + design docs + status + code. `docs/tasks.md` is always overwritten, never accumulated. This prevents stale task drift.
4. **Working language detection**: All agents detect the project's working language from existing `docs/` files and write in that language. Technical terms are preserved as-is.
5. **PRDs organized by feature, design docs organized by engineering domain**: PM writes CUJ-driven PRDs per product feature. TL writes design docs per engineering component/subsystem. Multiple PRDs may feed into one design doc; one PRD may require updates to multiple design docs. This decoupling prevents artificial 1:1 constraints.
6. **Design docs as one coherent body**: All files in `docs/design/` form a single comprehensive engineering design document — individual files are chapters. `system.md` covers cross-cutting concerns; `design-<slug>.md` files cover component-specific design. The TL always reads ALL design docs before making changes to maintain consistency.
7. **Separate pipelines for features vs. bugs**: Feature work flows through the full PM → TL → Planner → Execute → QA pipeline via `/design-feature` + `/dev-cycle`. Bug fixes use a lightweight `/report-bug` → `/triage` → `/quick-fix` path that bypasses PRDs and design docs (the spec isn't wrong, the code is). Triage routes the rest: large bugs that reveal design flaws are queued for `/dev-cycle`; bugs that reveal *spec* flaws go to `/design-feature` (Route C or D).
8. **Issues inbox, not issue tracker**: `docs/issues.md` is a write-only intake queue — anyone can jot down a problem. Triage diagnoses entries and routes them — run-now routes execute in the triage session; queued routes are taken by the owning loop's next run, which reports what it took and removes the entry once the fix is confirmed. Nothing sits unrouted, and no loop reads the inbox except for entries explicitly routed to it. Resolved entries are removed. History lives in git log, not in the inbox.
9. **QA as a gate, not a reporter**: `qa`'s verdict in `docs/qa-report.md` is binding, and its roll-up is mechanical (any bug ⇒ FAIL, any BLOCKED CUJ ⇒ BLOCKED — see the QA agent's "Overall verdict"). `/dev-cycle` turns it into retry / advance / blocked by bug severity (Phase 4), the planner schedules every MEDIUM+ bug above new work, and the loop cannot reach `done` without it. QA gates CUJs, not planner tasks — tasks are per-iteration scaffolding (see #3).
10. **Orthogonal QA dimensions**: Every QA finding has a Result (PASS/FAIL/BLOCKED/NOT_RUN/WAIVED, plus CUJ-level UNIMPLEMENTED — nothing built yet, excluded from the verdict but still unfinished work), Coverage (automated/manual/both/none), and Bug attributes (Severity × Kind). Severity drives the loop's retry decisions; Kind is descriptive.
11. **Two-run flakiness detection**: QA walks every CUJ twice with a fresh browser session. Inconsistent results between the runs are logged as `[FLAKY]` and treated pessimistically as FAIL — catching the failures that hide on a single pass.
12. **Visual fidelity via mocks under `docs/ux/`**: Mocks live at `docs/ux/<prd-dir>/cuj-<id>-<state>.<ext>`. QA discovers them by glob, compares to the running product side-by-side, and logs `[VISUAL_DEVIATION]` findings by severity. Missing mocks → log `NO_MOCK`, continue without blocking.
13. **Mocks produced during design, not as an async handoff**: The same `pm` agent that drives `/design-feature`'s discovery and CUJ-shape iteration also produces the HTML mocks — synchronously, in lockstep with shape iteration. Mocks save to `docs/ux/<prd-dir>/cuj-<id>-<state>.html`. The dev-cycle's Mocks Check is a fallback for CUJs that never went through `/design-feature` (e.g., backfilled by `/organize-project`); when found, it points the user to `/design-feature` Route D to add the mocks.
14. **Deterministic verdict**: `/dev-cycle`'s final phase derives DONE/CONTINUE/BLOCKED mechanically from QA's verdict, PM's per-CUJ verdicts in `docs/pm-review.md`, and whether any `blocking` ENG entry remains open. No additional agent call needed.
15. **Four-way role split: design / decompose / implement / verify**: `tl` designs (read code → propose architecture → maintain `docs/design/`); `planner` decomposes (read PRDs + design + status → propose tasks → write `docs/tasks.md`); `coder` implements (read task → write code + unit tests → commit); `qa` verifies (read PRDs + code + running product → write integration/E2E tests → produce `docs/qa-report.md` with gate authority). No role does another's work. tl doesn't write feature code; planner doesn't pick the architecture; coder doesn't write E2E tests; qa doesn't write unit tests. Each role's "What NOT to do" list enforces the boundary, so the orchestrator has clear delegation rules and any new requirement routes to exactly one owner.
16. **Roles define the craft; invocations define the interaction contract**: agent definitions keep their interactive behaviors (planner's plan approval, pm's clarifying-question cadence, tl's discuss-first rule) because those are good behavior when a human is driving — but they are explicitly scoped to interactive invocations. Orchestrators (`/dev-cycle`, `/design-feature` Phase 1) prepend a standard **autonomous preamble** to every subagent prompt: no user is available, don't ask or wait for approval, resolve ambiguity prompt → docs → sensible default, and return `BLOCKER: <description>` for genuine contradictions. The orchestrator handles any BLOCKER by setting `docs/loop-state.md` to `blocked` and stopping — so human judgment re-enters at the loop boundary, where a human actually exists, instead of deadlocking mid-subagent. Two structural consequences: `planner` has an explicit Modes section (approval gates interactive-only; in the loop, the QA and PM gates *are* the approval), and `pm` declares its three execution contexts (design partner / PRD writer / reviewer) — the conversational design rules bind the `/design-feature` orchestrator that runs them in the main thread, not the non-interactive subagent. Relatedly, PM review is **evidence-based**: pm has no browser tools, so its product-side verdict is grounded in QA's report, QA's walk screenshots under `docs/qa-artifacts/` (viewed multimodally), and the code — never phrased as if pm operated the product.
17. **Three intake tracks: defect / feature / engineering task**: work that is neither broken-from-the-user's-perspective nor a product feature — infrastructure, tooling, operational hardening, tech debt — has its own intake (`/eng-task` → `docs/eng-backlog.md`) instead of being forced into `issues.md` or a PRD. The backlog is deliberately a *backlog*, not an inbox: entries sit prioritized (`blocking`/`P1`/`P2`) until the planner schedules them, unlike issues.md which triage drains. Three invariants keep it from becoming a dumping ground: (a) every entry carries a **mechanically executable `Verify` check** filed at intake — since eng tasks bypass QA's CUJ walks and PM review, the Verify (run by coder, confirmed by tl at code review) is their entire functional gate; (b) `tl` owns the track end-to-end — files entries during architecture review, gates completions out at code review; (c) priority is a cross-source ladder the planner enforces: MEDIUM+ QA bugs > `blocking` ENG > CUJs interleaved with `P1` ENG > LOW bugs and `P2` ENG. `/dev-cycle` won't report `done` while a `blocking` entry is open; open P1/P2 entries persist across cycles by design.
18. **Document authority with a human apex: user intent > PRD > design docs > tasks.md**: lower documents are derived views, and *silently resolving* a contradiction is prohibited everywhere — `planner` plans per the PRD, cites the governing criterion in the task spec, and records the conflict; `tl` reconciles design docs with the changed PRDs as the diff baseline (dev-cycle Setup computes the changed-PRD list) and never authors a rationale for stale design-doc content; `coder` stops with a BLOCKER when a task spec contradicts the PRD it cites; `qa` takes acceptance criteria from PRDs only. The hierarchy is topped by **user intent** because a PRD is authoritative only as the serialization of what the user decided — so an ad-hoc user-directed change ("make the button green") outranks the PRD and creates a **spec-sync obligation** rather than a conflict: the contradicted PRD lines and mock tokens get minimal, user-confirmed, docs-only amendments (`/quick-fix` runs the check automatically after every fix; `/spec-sync` covers changes made outside it; triage's `spec-stale` classification routes deliberate deviations there). This closes both failure directions at once: stale design docs can no longer override fresh PRDs (the post-mortem case), and stale PRDs can no longer trigger revert wars against intentional changes (the green-button case). The sole carve-out to pm's PRD ownership is spec-sync's amendment power — user-present, line-scoped, commit-trailed.
19. **Graded quality is its own loop, with separation of powers so it can't Goodhart itself**: statistical output quality (summaries, rankings, extractions, pipelines) breaks the dev-cycle's premise of deterministic, binary, cheap verification — so it gets a parallel spec–measure–improve triangle where **the bar-setter, the measurer, and the improver are never the same agent**: pm + user calibrate the bar into `qspec.md` (anchored scales where every anchor cites a real example — the golden-examples analog of mocks-in-lockstep); `evaluator` measures with validity tripwires that halt rather than fabricate (judge calibration gate against the user's labels, noise floor from double-run baselines, holdout custody, budget ledger); `researcher` + `coder` improve via one-mechanism-per-iteration experiments, with the append-only lab notebook as the sanctioned stateful exception (negative results are load-bearing — an improver with amnesia re-runs its failures). Generality comes from measurement-shape dispatch (absolute-graded / comparative / ground-truth / proxy), not per-domain instructions — shape references grow on pilot evidence, not speculation. The loop's verdicts include **plateau as a first-class ending**: k experiments without accepted improvement is a product tradeoff returned to the user, not a failure to push through. qa keeps the deterministic envelope and never vibe-checks generated content; dev-cycle runs a smoke-eval when tasks touch quality-surface files; the per-cycle user spot-check is the standing human anchor that keeps an autonomous improver aimed at the user's bar rather than the judge's drift.
20. **Measurement corpora are projections of the qspec, never independent artifacts** (first field cycle, F1–F4): a gold corpus built before the bar exists is provisional by definition — "perfectly replicating a deficient gold standard still fails." `/design-quality` therefore inventories pre-existing measurement assets up front and audits them in **one consolidated pass** right after the qspec lands (Phase 3.5: lint every mechanical rule via per-rule corpus linters, class-group the discrepancies, one rulings batch, one ENG wave) instead of letting mismatches surface drip-wise. Corpus changes thereafter follow the **Corpus Revision Protocol** (versioned baselines, carry-over snapshots, monotone ratchet floors, errata citing their authorizing ruling — never silent edits). Honest caveat from the field ledger: whether an up-front protocol would have prevented the original incidents, or incident-driven growth is what made it fit, is genuinely unknown — both readings are recorded.
21. **Owner throughput is the pipeline's scarcest resource — budget it like one** (first field cycle, F5, F7–F13): every owner decision lives in one queue (now project-level `docs/owner-queue.md` — decision #22; the first field cycle's per-slug `rulings.md` was this decision's prototype; answerable inline or in conversation — the file is the record, not the channel), and the reporter's `status.md` carries a pointer + count to it (the queue file itself names each entry's **current producer** — a handoff that doesn't update it is the violation). Coordination artifacts hold pointers, not narratives — *one fact, one home; queue rows are ID + one line + status word* — because temporary artifacts drift into second state stores by default. Eng dispatch is owner-carried by default in **waves** (`/dev-cycle eng [--for <area>]`: one command drains a batch, exit report leads with the closed/filed/blocking net line), with orchestrator auto-dispatch only under a standing authorization recorded as a ruling. Reports separate change-narration from action-requests so the ask is never buried in the audit trail.
22. **Owner decisions ride a cross-track rail: a drained queue + a standing-rulings registry, split by lifecycle** (third field retro — the owner: "I have to hunt everywhere for the things that need my attention"): `docs/owner-queue.md` holds everything currently blocked on the owner and nothing else — human-first format (headline question, options with exactly one recommendation, a default with an arming trigger, an answer slot), oldest on top, written in the working language, closed entries deleted (history = git log, the issues.md doctrine — the queue trends toward empty); `docs/rulings.md` holds standing rulings only — append-only, agent-facing, cited by R-ID (one namespace; entries keep their number when promoted). Classification happens **at close, not at filing** — *does this answer govern cases nobody has looked at yet?* — because you often can't know at filing whether an answer will generalize. An **admission gate** keeps it a queue, not a feed: an item enters only when a pipeline is blocked-or-wrong without the answer AND no lower authority (planner ladder, triage table, qspec thresholds, ENG priority) decides it — no FYIs; rows are pointers to the item's home track, never copies. Every decision-making shared-checkout role carries a push-side **registration duty**, stated as a standing write grant that overrides each role's own write list (worktree agents excepted: coder's channel stays `BLOCKER:` and the orchestrator registers, because branch writes die with rejected branches; reporter excepted: it derives, never decides); `docs/rulings.md` is written only by whoever closes an entry; decision-class AskUserQuestions are registered before being asked, so declined and session-killed questions survive; content-confidential items (holdout spot-checks) get existence-stubs with a reconstruction path while contents stay message-only. Drainage is designed in, not hoped for: transient entries arm defaults the per-iteration Setup **sweep** applies; every exit report carries the queue delta + oldest-age line; `scripts/owner-lint.sh` enforces zero *marked* scatter (a vocabulary ratchet, stated as such) with RED defined as ownerless-remediable so the pipeline never blocks on hygiene. Queue size thereby becomes a diagnostic: steady growth means some pipeline is missing a rule and asking where it should be deciding. Alongside, the `status` agent was renamed **`reporter`** — every other agent is named for its role, this one was named for its artifact, and the word collided with three unrelated "status" vocabularies; its charter is now explicit (sole owner of the human-facing view; derives, never decides; its owner section is a pointer + count, never a second record).
23. **A constraint with no stated reason is a question, not a rule — and asking it is tl's job** (field case: a 1000-line code cap inherited from a pasted brief was specified faithfully, budgeted by tl to a 30-line margin and filed as a risk, and surfaced only when coders hit it mid-build — with escalation options that all kept a cap). The split follows the roles: pm captures product requirements as given — "lightweight" is a legitimate requirement, and interrogating it isn't design's job. The concrete number standing in for it is an architecture decision, so `tl` reviews every implementation-shape constraint (numeric limits, technology bans/mandates, platform rules) at its first design pass and on every PRD change, classifying each by what it rests on: an external fact (verify, design within), an owner decision with a recorded reason (design within, state heavy costs once), or nothing recorded (raise it now — `BLOCKER` when it would reshape the architecture, so the question arrives before any code exists). The review is recorded in `system.md`'s Constraints table, so each constraint is examined once. Every requirement challenge, whoever raises it, follows one format: the headline questions the constraint itself, its origin and reason (or "none recorded") are stated, "drop it" is always an option, and every number states its basis. Rulings are durable; one that changes a requirement routes to pm for a line-scoped PRD amendment citing the R-ID.
24. **The owner supervises at architectural seams, so the loop pauses on a tl-authored checkpoint ladder — one mechanism, two rung kinds, approved once as a plan** (owner retro: "I'd love to look when the APIs are defined, then when the first batch is implemented — not wait until the whole feature exists; the feature itself can be a very deep stack"). The end-to-end loop had exactly two human boundaries, `done` and `blocked`; everything between them was the planner's parallelism-first cut, which produced states nobody could usefully inspect. The fix is *not* PM-defined product milestones — those sit on CUJ boundaries and force the whole stack before the first look — but a ladder of **seams** in `system.md`'s Build Order & Checkpoints, authored by `tl` because tl owns the seams: **seam rungs** (a contract, a layer, a batch of endpoints; poked by a command; gated by an executable Verify like an ENG entry, confirmed at code review) and **journey rungs** (a CUJ set usable end to end; poked by walking it; gated by the existing two-key gate scoped to those CUJs — so `done` is simply the last journey rung). PM authors no second ladder: its inputs are already in the PRD (Priority, Dependencies, MVP scope); tl cuts the slices from them, the first slice thin through every layer with dense rungs, tapering afterward. Three invariants: **no poke, no rung** (a rung the owner can't inspect in a minute is a status line, and the poke action is planned as part of the rung's work); **the ladder is plan, not progress** (reached rungs live in loop-state and status.md); **never silently modified** (a changed ladder re-enters review as a diff). The owner's interaction has one shape at every pause — look, route (`/report-bug`, Route D, or tell tl), `continue` — and the **checkpoint plan review** (Phase 1.5, the first cycle after a PRD change) is the single queue-bearing pause: the whole ladder is presented as a plan with A approve / B change / C no pauses, no default, the ruling scoped to the PRD. Rung pauses are not queue entries — their only answer is running again. Run-through is a dial, not a mode: `--until done | Cn` on the invocation beats a standing no-pauses ruling in both directions, and passed-through rungs are still verified and recorded. Migration is free: a project without a ladder gets one for its remaining work and exactly one extra pause.
25. **Design docs have two readers, and the templates now serve the reviewer first** (owner retro: "when I'm reviewing a design doc I usually can't find the level of detail I want, or the high-level description I need to understand the overall architecture"). The quality bar named one reader — the implementing engineer — and every rule pushed depth ("never be brief", "always go deep"); nothing rewarded findability. Field evidence across three projects: `system.md` had a checklist but no template, so each tl numbered it differently; the component template's inner headings (Data model / Interface contract / Logic & behavior) survived intact in only 3 of 23 chapters, displaced by project-named subsections, so the detail existed but never where a reader could predict; Overviews were one dense paragraph; and with no design-doc counterpart to "PRDs are pure spec", headers accreted iteration logs that became the first thing a reviewer saw. The fix is formatting discipline, not less depth: a fixed eleven-section `system.md` whose §1 is the system in one screen (architecture diagram, parts table, how-to-read table); a fixed eight-section chapter opening with an Overview card (responsibility / owns / exposes / depends on / used by / not responsible for) and a one-screen "How it works", with §4.1–4.3 non-negotiable and project structure nesting under them as H4; numbered sections, so the checkpoint ladder and cross-references point at "§4.2" rather than a title; **design docs are spec, never progress trackers** (the PRD rule, applied; progress lives in loop-state, status.md, git); and a layering rule that balances the depth rules — orientation on the first screen, depth in §4 — with a split trigger (ten H4s under 4.3, or ~1,000 lines). Sections scale with the project, numbering doesn't: what doesn't apply is omitted — never stubbed, never renumbered — so a small project is a short book with the same addresses. Existing docs are reshaped the next time tl touches them in a Phase 1 pass, not rewritten wholesale.
26. **Load-bearing decisions get the owner's eyes twice — on the design and on real data — whenever they appear** (ba-nana field retro: weeks of polish on one sample scenario reached a checkpoint, then ten minutes of the owner's unscripted use showed that screen dedup, the layer everything rests on, was wrong — "if we had pushed to the end and only then found it, how much would we tear down?"). Every gate counted evidence the pipeline produced itself; none counted distinct real inputs, so a decision backed by one scenario looked as settled as one backed by ten, and the gates rewarded fixing every quirk of the one scenario available. The fix adds no phase state and no rung kind. tl marks the one to five decisions everything rests on with two `system.md` §9 columns — the code paths each owns, and the real samples it has held on. Each gets a design brief at the plan review and a **validation rung** (a seam rung proving it on named real samples with expected outcomes, owner-supplied when only the owner can produce them) before anything builds on it. Both fire at any stage: a new feature, tl's own revision, a bug whose root cause lands in owned paths (triage matches files mechanically, and the fix goes through tl), or the owner naming a gap. Run-through skips progress pauses but never these two stops. **Breadth before depth**: MEDIUM bugs inside an unproven decision's paths defer to its validation rung, where tl fixes them by mechanism and re-tests one-scenario patches on every sample — promoted or deleted.

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
│   ├── reporter.md                 # Project reporter agent (human-facing view; renamed from status)
│   ├── gorilla.md                  # Adversarial exploratory test agent (black-box destructive)
│   ├── evaluator.md                # Quality measurement institution with gate authority (judge, eval sets)
│   └── researcher.md               # Empirical quality scientist (diagnosis, experiments, lab notebook)
└── commands/
    ├── design-feature.md           # Design a feature (bootstrap / new PRD / extend / refine)
    ├── dev-cycle.md                # Autonomous loop command (one iteration)
    ├── report-bug.md               # Conversational bug intake with screenshot support
    ├── triage.md                   # Issue diagnosis and scope assessment
    ├── quick-fix.md                # Small-scope bug fix
    ├── spec-sync.md                # Reconcile PRDs/mocks with intentional out-of-band changes (docs-only)
    ├── eng-task.md                 # Engineering-task intake with mandatory executable Verify
    ├── gorilla-test.md             # Manual adversarial exploratory test session
    ├── organize-project.md         # Retrofit an existing project into the canonical pattern (one-time-per-project)
    ├── design-quality.md           # Calibrate a quality bar into a measurable spec (qspec + judge + eval set)
    ├── quality-cycle.md            # Autonomous quality-improvement loop for one surface
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
    │   ├── system.md               # cross-cutting design + checkpoint ladder (canonical name)
    │   └── design-<slug>.md        # per engineering component
    ├── ux/
    │   └── prd-NNN-<slug>-mockups/
    │       └── cuj-<id>-<state>.html  # mocks produced by pm during /design-feature
    ├── tasks.md                    # planner output; overwritten each cycle
    ├── status.md                   # reporter agent output (file keeps its historical name)
    ├── owner-queue.md              # everything currently waiting on the owner — human-first,
    │                               # drained (closed entries leave the file; history in git log)
    ├── rulings.md                  # standing-rulings registry — append-only, agent-facing,
    │                               # entries promoted from the queue at close, cited by R-ID
    ├── qa-report.md                # QA agent output
    ├── qa-artifacts/<run-id>/<cuj-id>/run{1,2}/    # <run-id> = iter<N>-<HH-MM-SS>; gitignored
    │   └── *.png                   # screenshots from the QA walks (pm reads them from disk)
    ├── loop-state.md               # iteration counter + last verdict + reached checkpoint rungs
    ├── issues.md                   # bug intake (h3-block format, written by /report-bug and gorilla)
    ├── issues-attachments/         # bug screenshots — gitignored, deleted on /quick-fix
    │   └── <issue-id>-<N>.png      # one per attached screenshot
    ├── eng-backlog.md              # engineering-task backlog (ENG-NNN h3 blocks with mandatory
    │                               # Verify; written by /eng-task, tl, /triage; closed by tl
    │                               # review or /quick-fix; Next-ID counter in preamble)
    ├── quality/                    # graded-quality framework (one dir per quality surface)
    │   └── <slug>/
    │       ├── qspec.md            # the bar — pm-owned pure spec (dimensions, anchors, thresholds)
    │       ├── calibration/        # user-labeled examples grounding the judge
    │       ├── evalset/{dev,holdout}/  # evaluator's custody; holdout never visible to improvers
    │       │   └── smoke.txt       # fixed ~10 dev case IDs for smoke runs (gen by coders, scored by evaluator)
    │       ├── judge/              # judge prompts per dimension + calibration record,
    │       │                       # linters/ (one per lintable rule), experiment-scoring.md
    │       ├── eval-report.md      # evaluator output: scores × strata, taxonomy, gate verdicts
    │       ├── experiments.md      # researcher's append-only lab notebook
    │       ├── ledger.md           # eval-run budget ledger
    │       ├── quality-loop-state.md   # /quality-cycle iteration state
    │       └── runs/               # raw run artifacts — gitignored
    ├── gorilla/                    # per-session gorilla output (chronological history)
    │   └── <session-id>/
    │       ├── report.md           # this session's summary (committed)
    │       └── screenshots/        # this session's screenshots — gitignored
    │           └── <NN>-<slug>.png
    └── *-guidelines.md             # optional mandatory rules picked up each cycle
```

---

## 1. Agent Model Selection

Agents are assigned **capability tiers** rather than vendor-specific model names. Each platform maps tiers to its own models. This keeps the setup portable — the tier captures *what the agent needs*, not which product provides it.

### Tiers

| Tier | Purpose |
|------|---------|
| `max` | Highest reasoning ceiling — design decisions, gate verdicts, complex architecture |
| `strong` | Solid reasoning at better cost — implementation, task decomposition, diagnostics |
| `fast` | Lightweight — summarization, reporting, templated transforms |

### Agent → tier assignments

| Agent | Tier | Rationale |
|-------|------|-----------|
| `pm` | max | Design + PRD writing need the highest reasoning ceiling |
| `tl` | max | Architecture decisions and code review need the highest reasoning ceiling |
| `planner` | strong | Task decomposition quality drives the whole pipeline |
| `coder` | strong | Implementation quality — the main cost center; demote to `fast` for simple projects |
| `qa` | strong | Gate authority — must catch subtle bugs and fabrications |
| `evaluator` | strong | Statistical measurement integrity is load-bearing |
| `researcher` | strong | Hypothesis quality determines improvement velocity |
| `gorilla` | strong | Adversarial creativity benefits from strong reasoning |
| `reporter` | fast | Lightweight summarization of existing docs — no reasoning-heavy work |

The **main session** (orchestrator) typically runs on the `max` tier — it drives multi-agent coordination, interprets user intent, and makes routing decisions.

### Platform model mappings

| Tier | Claude Code | Codex | Gemini CLI |
|------|-------------|-------|------------|
| `max` | `fable` | *(not yet supported)* | *(not yet supported)* |
| `strong` | `opus` | *(not yet supported)* | *(not yet supported)* |
| `fast` | `sonnet` | *(not yet supported)* | *(not yet supported)* |

Model aliases (e.g., `opus`) resolve to the latest version of that family at runtime. Pin to an exact ID (e.g., `claude-opus-4-6`) when you need stability across deploys. A platform with only two model tiers maps both `max` and `strong` to the same model.

### How model selection reaches each platform

| Platform | Agent format | Model field | Where to set |
|----------|-------------|-------------|--------------|
| Claude Code | `claude/agents/*.md` (YAML frontmatter) | `model:` in frontmatter | Edit the `.md` file directly |
| Codex | `codex/agents/*.toml` (generated by `sync-from-claude.sh`) | Not carried through yet — Codex uses its platform default | Add `model` to the sync script's `write_agent()` once Codex supports per-agent models |
| Gemini CLI | TBD | TBD | TBD |

The **main session model** (the orchestrator / interactive agent) is set per-platform in platform-specific config (Claude Code: `claude/settings.json` → `"model"`) and is independent of agent tiers.

### How to update

- **Change an agent's tier**: update the tier table above → edit the `model:` field in that agent's definition for each platform that supports it.
- **Change a platform's model for a tier**: update the platform mapping table above → edit every agent at that tier on that platform.
- **Add a new platform**: add a column to the platform mapping table → implement model resolution in that platform's deploy/sync script → document the agent format and model field in the "How model selection reaches each platform" table.

---

## 2. Settings: `~/.claude/settings.json`

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
  "effortLevel": "xhigh",
  "theme": "dark-daltonized",
  "model": "claude-fable-5-1[1m]"
}
```

Add more `Bash(<prefix> *)` entries as needed for your stack (e.g., `Bash(swift *)`, `Bash(bun *)`, `Bash(cargo *)`).

---

## 3. Global Instructions: `~/.claude/CLAUDE.md`

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

## Continue the loop

When I say "continue", "go on", "继续", "続けて", or similar after a `/dev-cycle`
pause (status `checkpoint`): run `/loop /dev-cycle` — it iterates until the next
pause (a checkpoint rung, done, or blocked). `/dev-cycle` alone is one iteration.

When I say "run through", "no checkpoints", "build it end to end", "一口气做完",
or similar: run `/loop /dev-cycle --until done`. "Run to C4" / "stop at C4" →
`/loop /dev-cycle --until C4`.
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

If you'd rather not symlink and want a static copy, just `cp -r claude/agents claude/commands claude/CLAUDE.md claude/settings.json ~/.claude/`. Trade-off: edits to the repo no longer flow into `~/.claude/` automatically. (After the `status` → `reporter` rename, copied installs must also delete the stale `~/.claude/agents/status.md`.)

### Migrating a deployed project to the owner-decision rail

One-time, for projects that predate design decision #22: merge each `docs/quality/<slug>/rulings.md` into the project-level files — pending entries → `docs/owner-queue.md`, ruled entries → `docs/rulings.md` (IDs kept, `Scope: quality/<slug>` added; renumber via a mapping table only on collision). Any interim owner-inbox file merges the same way. Legacy pending-owner scatter elsewhere (loop-state "Next Focus" items, ad-hoc STATUS action-queue sections, notes inside ENG entries) becomes R-NNN pointers; `scripts/owner-lint.sh` — generated by the next `/dev-cycle` Setup — turns any stragglers red. Archive superseded per-slug rulings files with a header pointer rather than deleting them: their ruled entries are already in the registry, and old errata citations stay resolvable.

### Bootstrap without the repo

If you don't have this repo cloned but want to recreate the setup from scratch, the source of truth for every agent and command lives at the linked files in the [agents/](agents/) and [commands/](commands/) tables above. Read each linked file and copy its content to the corresponding path under `~/.claude/`. The settings and CLAUDE.md content are inlined in Sections 1 and 2 of this doc respectively.

Then verify with:
- `/user:pm` — should respond as PM
- `/user:tl` — should respond as architect
- `/user:planner` — should respond as planner
- `/user:coder` — should respond as implementation specialist (writes code + unit tests; refuses to modify PRDs / design / tasks)
- `/user:qa` — should respond as QA
- `/user:reporter` — should respond as the project reporter and generate `docs/status.md` (the artifact keeps its name; the agent was renamed from `status`)
- `/user:gorilla` — should respond as the gorilla testing agent (refuses to read PRDs/code before attacking)
- `/user:evaluator` — should respond as the quality-measurement institution (refuses to fabricate scores or diagnose causes)
- `/user:researcher` — should respond as the quality scientist (refuses to touch eval sets, judge assets, or the qspec)
- `execute tasks` — main agent should read docs/tasks.md and spawn worktree agents with `subagent_type: "coder"`
- `/design-feature "test pitch"` — should detect context (brand-new vs existing project), drive conversational discovery in the main thread, and route to bootstrap / new PRD / extend / refine
- `/dev-cycle` — should run one full autonomous iteration; on a project with no approved checkpoint ladder it should stop after architecture review and present the checkpoint plan (A approve / B change / C no pauses)
- `/report-bug "test bug"` — should drive conversational intake, attempt screenshot capture (prompts you through the options), write an h3 block to `docs/issues.md`, and ensure `docs/issues-attachments/` is in `.gitignore`
- `/triage` (or `/triage <issue-id>`) — should diagnose open issue blocks, append a `Triage` field (with Route) to each, then hand each off — running `/quick-fix` / `/spec-sync` / `/design-feature` now, or reporting it as queued for `/dev-cycle` / `/quality-cycle`
- `/quick-fix <issue-id>` — should fix the issue and remove the block + its referenced screenshots
- `/spec-sync` — should scope the reconciliation (description / CUJ / commit range / recent delta), find the exact contradicted PRD lines and mock tokens, and propose minimal user-confirmed amendments
- `/eng-task "test task"` — should apply the classification rule (redirecting defects/features), drive conversational intake, refuse to file without a mechanically executable `Verify`, write an h3 block to `docs/eng-backlog.md` (creating it with the `Next-ID:` preamble on first use), and offer `/quick-fix ENG-NNN` for small entries without Ordering constraints
- `/gorilla-test --time 5m` — should set up a session, ensure the dev server is up, spawn the gorilla, and file any reproducible findings to `docs/issues.md` (use a tiny budget to spot-check the wiring; for a real session use 30m+)
- `/organize-project` — in a project that has working code but no `docs/prd/`, should audit existing markdown broadly, propose how to reconcile non-canonical docs, scaffold infrastructure, and backfill PRDs + design docs from the code. Idempotent — re-running on an already-organized project should be a near-noop
- `/design-quality "<surface>"` — should identify the quality surface and confirm the measurement shape, then drive a calibration conversation on real candidate outputs (requires a built quality-bearing feature; ends with a calibrated judge + seeded eval set or an honest BLOCKED)
- `/quality-cycle <slug>` — should run the instrument check first and refuse to loop without a calibrated judge, then iterate measure → diagnose → experiment → gate within the qspec's eval budget
- `/worktree-start test-parallel` — should create `../<repo>-test-parallel` on a new `feature/test-parallel` branch and open it in a new Antigravity window
- `/worktree-sync` (from inside that worktree, after committing something) — should two-way merge with main and leave the worktree intact
- `/worktree-finish` (from inside that worktree, when done) — should merge into main with `--no-ff`, remove the worktree, delete the branch
- `/loop /dev-cycle` — should run autonomous iterations until the next pause: a checkpoint rung, done, or blocked (`--until done` runs through; `--until C3` pauses at that rung)
