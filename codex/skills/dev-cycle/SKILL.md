---
name: "dev-cycle"
description: "Run one iteration of the autonomous development loop. Orchestrates tl, planner, task execution, qa, reporter, and pm agents in sequence; pauses at the checkpoint rungs the owner approved. Updates docs/loop-state.md with iteration progress."
---

<!-- generated-from: claude/commands -->

# dev-cycle

Use this skill when the user asks to run `$dev-cycle`.

> **Codex runtime notes** — this text was written for Claude Code; on Codex read it as follows.
> - A slash command `/name` is the Codex skill `$name` (already rewritten below). `/loop $x` means: run `$x` again in this same turn after each stop that is not final, until it reports a stopping status (`checkpoint`, `done`, `blocked`, or the `--until` target).
> - "Spawn a `<role>` subagent" / `agent_type: "<role>"` → `spawn_agent(agent_type="<role>", task_name="<label>", message=<the full prompt>)`, then `wait_agent` to collect. The roles are the `~/.codex/agents/*.toml` custom agents: tl, planner, coder, qa, reporter, pm, evaluator, researcher, gorilla. A subagent's final message is its return summary.
> - "Spawn all in a single message" / `run_in_background: true` → call `spawn_agent` for every one of them in the same turn, then `wait_agent` for all.
> - `isolation: "worktree"` → Codex subagents share your checkout and sandbox. Give each one its own `git worktree add .worktrees/<branch> -b <branch>` inside the repo and tell it to work and commit only there; merge, then `git worktree remove`. The `$dev-cycle` skill's "Codex adaptations" section has the full recipe.
> - `AskUserQuestion` → there is no blocking question tool outside Plan mode. Do the registration the text asks for first, then put the question and its options in your final message and end the turn; the next run picks the answer up from the owner queue or the chat.
> - Claude tool names (Read, Grep, Glob, Edit, Write, Bash, WebSearch, WebFetch) are your shell, `apply_patch`, and web tool; Playwright MCP tools are the browser plugin as described in the qa role.
> - `~/.claude/agents/*.md` and `~/.claude/commands/*.md` are `~/.codex/agents/*.toml` and `~/.codex/skills/*/SKILL.md`; `CLAUDE.md` is `AGENTS.md` (already rewritten).

## Command Template

# Dev Cycle — One Iteration

You are the orchestrator of one autonomous development iteration. Execute the following phases in order. After each phase, record progress in `docs/loop-state.md` before continuing.

## Setup

First, check if the user specified a **target PRD** (e.g., `dev-cycle prd-008`). If they did, this cycle is **scoped** — all phases only work against that single PRD file (`docs/prd/prd-008-*.md`). If no target is specified, the cycle works against all active PRDs.

Throughout these instructions:
- **Scoped mode**: replace every mention of "active PRDs under docs/prd/" with the specific target PRD file path. Subagent prompts must name the exact file so agents don't wander into unrelated PRDs.
- **Unscoped mode**: use all active PRDs as before.

**Eng-wave scope** — `dev-cycle eng` (all eligible open ENG entries), `dev-cycle eng ENG-012,ENG-014` (named entries), or `dev-cycle eng --for <area>` (entries whose `Relates-to` matches, e.g. `--for quality/summary`). An eng-scoped cycle **drains a backlog wave in one command** — the counter to the documented failure mode where the owner hand-carried a dozen-plus tickets one at a time. Phase adjustments:
- Skip the Mocks Check and Phase 6 (no CUJs in scope). Phase 5 (reporter) runs only if entries closed.
- Phase 1 (tl): review only the design impact of the in-scope entries.
- Phase 2 (planner): plan *only* the in-scope entries, grouped by their `Ordering` constraints and dependencies — carry each entry's `Verify` into the task's "Done when."
- Phases 3 / 3.5 / 3.6 run normally; tl's review confirms each entry's Verify evidence and removes completed blocks from `docs/eng-backlog.md`.
- Phase 4 (qa): full test suite + quality-surface smoke checks only — no CUJ walks.
- Verdict: `done` when every in-scope entry's Verify passed and its block is removed. The exit report **leads with the net line**: `closed <c> / filed <f> (<b> instrument-blocking) / remaining blocking: <n> / new defect classes: <yes/no>` — the owner decides "another wave?" from that one line, and `/loop $dev-cycle eng --for <area>` repeats waves until blocking count is zero or a non-mechanical item needs them.

Next, read `docs/loop-state.md` if it exists to understand the current iteration number and any carry-over context from the previous cycle. **Pay special attention to the QA Gate section** — if the previous iteration ended with QA FAIL, this iteration's Planner must prioritize fixing those failures before taking on new work.

Read `docs/prd/index.md`, all files under `docs/design/`, and `docs/eng-backlog.md` (if it exists — open engineering tasks; `blocking` entries factor into planning and the final verdict) to orient yourself.

**Routed issues.** Read `docs/issues.md` (if it exists) for the issues `$triage` routed to this loop — blocks whose Triage `Route` is `queued → $dev-cycle`. These are confirmed defects that need the full pipeline. Only you read the inbox: tl and the planner get each routed issue's ID, headline, CUJ, root cause, files, and Notes embedded in their prompts below. Scoped mode takes only issues whose CUJ field names the target PRD; eng-wave mode takes none.

**Determine which PRDs changed since the last cycle** (they drive Phase 1's design-doc reconciliation): `PRD_BASE=$(git log -n1 --format=%H -- docs/loop-state.md 2>/dev/null)`; if set, `CHANGED_PRDS=$(git diff --name-only "$PRD_BASE" HEAD -- docs/prd/)` plus any uncommitted changes (`git diff --name-only HEAD -- docs/prd/`). If no marker exists (first cycle) or the computation fails, treat **all active PRDs** as changed — over-reconciling is safe, missing a change is not.

**Checkpoint ladder and the `--until` flag.** The owner supervises the build at the rungs of the checkpoint ladder — `system.md`'s **Build Order & Checkpoints** table, authored by tl (rung kinds, format, and authoring rules live in tl's role definition). Read it if it exists, together with `docs/loop-state.md`'s Checkpoints section (which rungs are reached). Derive:
- **Active rung** — the lowest unreached rung; in scoped mode, the lowest unreached rung whose Scope touches the target PRD. No ladder yet → this cycle writes one (Phase 1) and reviews it (Phase 1.5).
- **Plan review due** — when `CHANGED_PRDS` is non-empty, or any active PRD has CUJs not covered by an approved ladder (`Approval: pending`, or a project that predates the ladder). The review runs once per PRD change, not every cycle. It also runs when tl reports load-bearing decisions new, changed, or reopened.
- **Deferred bugs** — MEDIUM bugs in `docs/qa-report.md` whose file matches a load-bearing decision's owned paths (`system.md` §9) while its validation rung is neither reached nor active. They count as LOW and the planner leaves them unscheduled, so one scenario's quirks aren't polished before the decision meets varied real data; once that rung is active, they are its work. HIGH and CRITICAL bugs are never deferred.
- **Run-through** — rung pauses are skipped when, in this precedence: the invocation says `--until done` (run to `done`/`blocked`) or `--until <Cn>` (pass every rung before `Cn` silently, pause at `Cn`); else a standing ruling in `docs/rulings.md` with `Scope: prd-NNN` says no checkpoint pauses for the PRD the active rung belongs to. The flag beats the ruling in both directions — `--until C3` pauses at C3 even under a no-pauses ruling, because the invocation is the owner's most recent intent. Run-through also skips Phase 1.5 — an unapproved ladder stays `pending` and is presented at the next cycle invoked without `--until` — except when load-bearing decisions are new, changed, or reopened. Eng-wave cycles have no rungs and never pause.

Run-through never skips `blocked` or a sample request, and never skips a rung's Verify: a passed-through rung is still verified and recorded as reached, so `status.md` shows when it was crossed.

### Guidelines Discovery

Run `ls docs/*-guidelines.md 2>/dev/null` to check for guideline files. If any `*-guidelines.md` files exist, read all of them before proceeding — they contain mandatory development and process rules that apply to every phase of this cycle. Store the list of discovered file paths and pass them to every subagent prompt below. If no guideline files exist, skip this step and proceed normally.

### Worktree Label

Compute a short worktree label so this cycle's subagents are distinguishable from any other Claude sessions running on the same repo (e.g., another `$dev-cycle` running from a different worktree, or the user editing in a parallel window). The label flows into FleetView via each subagent's `description` parameter.

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

This applies to every subagent spawned by this skill — tl, planner, qa, reporter, pm, and every task-execution worker. It does not change anything inside the subagent's prompt body; only the `description` (the visible label).

### Autonomous Preamble

Every subagent prompt this skill sends (tl, planner, qa, reporter, pm, and every task-execution coder) must **begin** with this paragraph, verbatim:

> You are running unattended inside an orchestrated pipeline; no user is available. Do not ask questions or wait for approval — approval and confirmation steps in your role definition apply only to interactive invocations. Resolve ambiguity in this order: this prompt → the project docs → the simplest reasonable default. If you hit a genuine contradiction you cannot resolve, stop and return "BLOCKER: <description>" as your final message.

This is what lets role definitions keep their interactive behaviors (planner's plan approval, pm's clarifying questions) without deadlocking the loop: the roles define the craft, the invocation defines the interaction contract, and human judgment re-enters at the loop boundary instead of mid-subagent.

**If any subagent's return contains `BLOCKER:`**, stop the cycle, register the blocker as a `docs/owner-queue.md` entry (per the Owner Decision Protocol below — this is the only registration path for worktree agents; when a shared-checkout agent already filed the entry and its BLOCKER cites the R-NNN, cite that one instead of registering a duplicate), set `docs/loop-state.md` status to `blocked` with the blocker text + its R-NNN under "Blocker", and notify the user — the same handling as Phase 1's tl blocker path, generalized to every phase.

### Owner Decision Protocol

Two project-level files carry every decision that waits on the owner. This is the canonical spec — `$quality-cycle`, `$design-quality`, `$triage`, and the role definitions inherit it by reference.

**`docs/owner-queue.md` — the queue.** Everything currently blocked on the owner, nothing else. Human-first and drained: a closed entry leaves the file (history is git log). Entries append at the bottom, so the oldest sits on top. Written in the project's working language — this is the most human-facing artifact in the repo. An entry fits on one screen; context beyond ~2 lines goes behind its home link. Create on first need:

```markdown
# Owner Queue

> Everything currently waiting on your decision — nothing else. Entries append
> at the bottom, so the oldest sits on top. Answer by writing under
> "your answer" (agents transcribe and clear the entry), or just say it in
> chat. When nothing is below the line, nothing is waiting on you.
Next-ID: R-001

---
```

Entry format — headline question · one metadata line · ≤2 lines of context with a link to the item in its home track · scannable options with exactly one recommendation · a default line · an answer slot:

```markdown
### R-014 · <one-line question>

waiting since iter-51 (3 iters) · <scope> · producer: <who is waiting>

One or two lines of plain context — why this is on the owner's desk and
what it unblocks. Details: [<home item>](<link into the owning track>).

- **A. <option>** — <consequence in one line>
- **B. <option>** *(recommended — <one-line why>)*

*Unanswered by <trigger> → B applies automatically.*   ← or: *No default — stays open.*

> **your answer:**
```

**Requirement challenges** — entries asking whether a requirement should stand: a constraint with no recorded reason, or a PRD limit the build can't meet as specified. Whoever raises one (tl at architecture review, the orchestrator registering a coder's `BLOCKER:`, qa, the planner) uses the entry format above plus four rules:
1. The headline questions the constraint itself — "Drop the 1000-line cap?", not "How do we fit in 1000 lines?"
2. The context names where the constraint came from (its PRD line, plus its origin if known — e.g. a pasted brief) and its reason, or "none recorded"; what holding it costs; and the goal it appears to stand in for.
3. The options always include dropping it (keeping the underlying goal as a design principle when there is one), alongside keeping it as a soft target, keeping it as a hard limit, and any real design alternatives.
4. Every number in an option states its basis ("~1500 = projected total at the current design") — no value appears out of nowhere.

No armed default: a ruling on a requirement is durable — it moves to `docs/rulings.md` with `Scope: prd-NNN`. A ruling that changes the requirement routes to pm: when the sweep processes the answer, spawn a pm subagent to amend exactly that PRD line, citing the R-ID (the ruling is the approval), so Phase 1 designs against the amended spec.

**`docs/rulings.md` — the registry.** Standing rulings only: class rulings, standing authorizations, threshold decisions — answers that govern cases nobody has looked at yet. Append-only, agent-facing, entries never deleted (agents and errata cite them by R-ID). Same ID namespace as the queue; an entry keeps its number when promoted. Registry entry = question + context + `**Scope**: <project | quality/<slug> | prd-NNN | eng>` + `**Ruling**: <answer + date (+ "defaulted" when it armed)>`.

**Admission gate.** An item enters the queue only if BOTH hold: (1) a pipeline is blocked, or will act wrongly, without the answer; (2) no lower authority decides it — the planner's priority ladder, triage's routing table, qspec thresholds, and ENG Priority all outrank the queue. New bugs/issues/detections go to their own track. **No FYIs, ever** — notifications belong in exit reports and `docs/status.md`. Queue rows are pointers to the item in its home track, never copies.

**Who writes.**
- Shared-checkout subagents (tl, planner, qa, evaluator, researcher, pm): file the entry the moment a non-blocking owner decision surfaces; cite its R-NNN in your own output. This is a **standing write grant**: appending an entry to `docs/owner-queue.md` is part of every listed role's write surface, whatever that role's own write list says. (reporter is not listed: it derives and never decides, so its work never waits on an owner answer.)
- `docs/rulings.md` is written only by whoever **closes** an entry — the orchestrator's sweep, or an interactive session receiving the owner's answer live. Subagents append to the queue, never to the registry.
- Orchestrators: register on every `BLOCKER:` return (the only path for worktree agents — coder never writes these files; a branch write dies with a rejected branch), on every `blocked` state write (the Blocker section cites the R-NNN), and **before** asking a decision-class `AskUserQuestion` (answered → transcribe and close the same turn; declined or unanswered → the entry stays). Interactive design/calibration conversations are exempt per-question, but anything still open when the session yields is registered first.
- The owner: any edit is legal and reads as a ruling. Deleting an entry = decline-to-rule; the default applies.

**Answers and close-time classification.** A conversational answer is transcribed into the entry before anyone acts on it. Closing asks one question: *does this answer govern cases nobody has looked at yet?* Durable → move the entry to `docs/rulings.md` with the Ruling filled. Transient → delete it once the acting track records the outcome. Answers given live in conversation skip the queue entirely (durable → straight into the registry; transient → the acting artifact is the record). "Park" = keep pending with a new trigger. **Arming discipline**: arm a default only when applying it wrongly is cheap to undo — transient items should almost always arm (they go stale; defer/skip is safe); durable rulings rarely should (a class ruling by timeout is a wrong rule silently governing everything downstream).

**Secrets.** For content-confidential items (holdout spot-checks and kin), the queue holds a stub: existence + a reconstruction path ("contents by message only; evaluator rebuilds from `runs/<id>`"). Contents never land in the repo.

**The sweep — run it now, every iteration, as part of this Setup:**
1. Read `docs/owner-queue.md` (absent and nothing to file → skip silently).
2. Process filled `your answer` slots: transcribe → route the outcome to its producer/track → close per classification.
3. Apply armed defaults whose trigger has passed: record as defaulted → close per classification.
4. Run `./scripts/owner-lint.sh` (generate it first if missing, per the spec below; committed, `chmod +x`). **Red** findings are ownerless-remediable — fix them now (register the scattered item, add the missing field, close the answered entry) and re-run. **Yellow** findings flow into the exit report's queue line.

Every exit report this skill produces carries one fixed line: `Owner queue: +<n> filed / <m> closed (<k> defaulted) / <j> open (oldest R-NNN, <i> iters)`.

**`scripts/owner-lint.sh`** — a **vocabulary ratchet**: it catches *marked* scatter, and that limit is by design. Exit non-zero when any RED holds; print YELLOW lines to stdout. Checks:
- RED: owner-pending vocabulary (`待 OWNER`, "blocked on owner", "awaiting owner", "needs owner", "owner approval", "pending owner", or the project-language equivalents) on a line in `docs/**/*.md` outside `owner-queue.md` without an `R-<digits>` ID.
- RED: an owner-section heading (`Owner Action Queue`, `Owner Queue`, `待 OWNER`) anywhere outside `docs/status.md` and `docs/owner-queue.md`.
- RED: `Status: blocked` in a loop-state file without an R-ID in its Blocker section.
- RED: a queue entry missing options, a recommendation, a default line (or explicit no-default), a home link, or its answer slot; or a filled answer slot not yet processed.
- RED: a registry entry without a `**Ruling**:`.
- YELLOW: an armed default past its trigger; an unarmed entry pending ≥ 3 iterations.

---

## Mocks Check

Mocks are normally produced during `$design-feature` Phase 0.5 alongside CUJ shape iteration — every CUJ that exited `$design-feature` should already have at least one mock file under `docs/ux/<prd-dir>/`. This check surfaces any CUJ that's missing mocks (typically: backfilled PRDs from `$organize-project` that didn't go through `$design-feature`, or CUJs added by manual `/user:pm` invocation without the conversational mock flow).

1. Identify in-scope CUJs:
   - **Scoped mode**: CUJs in the target PRD
   - **Unscoped mode**: CUJs across all active PRDs

2. For each in-scope CUJ, glob `docs/ux/**/cuj-<id>-*.{html,png,jpg,webp,md}`.

3. If every in-scope CUJ has at least one matching mock file, print one line ("Mocks present for all in-scope CUJs.") and continue to Phase 1.

4. Otherwise, list the CUJs missing mocks. Per the Owner Decision Protocol, register the choice as a `docs/owner-queue.md` entry first (recommended + default: Proceed — QA logs `NO_MOCK`; arm the default so an unattended loop doesn't hang), then use `AskUserQuestion` to ask the user to choose:
   - **Proceed without fidelity check** — QA will log `NO_MOCK` for these CUJs and skip visual comparison; functional verification still runs.
   - **Pause** — stop the cycle here so mocks can be produced via `$design-feature` Route D (refine the affected CUJs to add mocks).

   The handoff is just the slash-command invocation:

   ```
   $design-feature
   ```

   Then describe to the orchestrator that you want to add mocks for CUJ-<X>, CUJ-<Y> in prd-NNN-<slug> (Route D — refine). The orchestrator will walk through each CUJ's shape (confirming it matches what's already specified), produce the mocks, and save them under `docs/ux/<prd-dir>/`.

5. Either answer closes the queue entry (transient — transcribe, act, delete). If the user chooses **Pause**, mark `docs/loop-state.md` with status `blocked`, list the missing mocks under "Blocker" citing the entry's R-NNN, and stop. The user re-invokes `$dev-cycle` after running `$design-feature` to add the mocks.

---

## Phase 1: Architecture Review

Spawn a `tl` subagent:

```
Prompt: "Review the current project state and update docs/design/.

FIRST — reconcile design docs against changed PRDs. These PRD files
changed since the last cycle: [insert CHANGED_PRDS, or 'all active
PRDs' on the first cycle]. For each, cross-examine every design doc
that touches the same surface, line by line, with the PRD as the diff
baseline: the PRD outranks design docs on user-visible behavior, so
rewrite or delete any design-doc assertion that contradicts the
current CUJs/acceptance criteria. Never re-justify or author a
rationale for existing design-doc content that conflicts with the
PRD — correct it, or return BLOCKER if you believe the PRD itself
is wrong.

SECOND — constraint review (Section 5 of your role definition), for
the same PRDs: classify every implementation-shape constraint
(numeric limits, technology bans/mandates, platform rules) by what
it rests on, and record it in system.md's Constraints table. A
constraint with no recorded reason is a question, not a rule: file
it as a requirement challenge — and return BLOCKER citing its R-NNN
if the answer would change the architecture.

Then: are there design gaps relative to the PRDs? Are there
design decisions that need to be made before the next round of
implementation? Read docs/prd/index.md, active PRDs under docs/prd/,
all files under docs/design/, docs/status.md, and the codebase.
Update the appropriate design docs (system.md for cross-cutting,
design-<slug>.md for component-specific). If you identify needed
engineering work with no product surface (infrastructure, tooling,
operational hardening, tech debt), file it as an ENG entry in
docs/eng-backlog.md per Section 6 of your role definition — every
entry needs a concrete, executable Verify check.

THIRD — checkpoint ladder (Checkpoint ladder, Section 5 of your role
definition): [no ladder exists → "Write system.md's Build Order &
Checkpoints for the active PRDs. Where work is already in place, list
the load-bearing decisions already built and put their validation rungs
first, then cover the remaining work." | CHANGED_PRDS
non-empty → "Append or adjust rungs for the changed PRDs: <list>; set
Approval back to pending and list the diff against the approved
version in your summary." | otherwise → "The ladder is approved
(R-NNN); change it only if the design changed underneath it, and
report any change as a diff."]

Also review the design implications of these defects triage routed
to this loop (each needs the full pipeline): [embed each routed
issue's ID, headline, CUJ, root cause, files, and Notes — or 'none'].

FOURTH — load-bearing decisions (Section 5 of your role definition):
mark new ones (none marked yet → the ones already built), revise
changed ones, and reopen any whose owned paths hold a routed defect's
root cause. [active rung proves a D-n → "The active rung proves D-n:
design its fixes by mechanism, from its failing samples and these
deferred bugs: <list>."]

Return a summary of:
1. What design decisions were made or updated
2. What ENG entries you filed (IDs), if any
3. What constraints the planner should know about
4. Any blockers that require user input before work can proceed
5. Requirement challenges filed (R-NNN), if any
6. The checkpoint ladder: new | changed (with the diff against the
   approved version) | unchanged
7. Load-bearing decisions: new | changed | reopened (D-IDs, each with
   what changed and what built work it touches) | unchanged"
```

If tl reports a **blocker requiring user input**, stop the loop, update `docs/loop-state.md` with status `blocked`, and notify the user with the blocker details.

---

## Phase 1.5: Checkpoint Plan Review

Runs when Setup found the plan review **due** and the cycle is **not** in run-through mode — and in every mode when tl reports load-bearing decisions new, changed, or reopened. This is where the owner sees, in one place, where the loop will pause for them — and approves or reshapes it before the planner writes a single task.

1. **Register first.** Per the Owner Decision Protocol, append a `docs/owner-queue.md` entry — headline `Approve the checkpoint plan for <prd list>?` (`Approve D-n, … and the checkpoint plan?` when load-bearing decisions are up for review); options exactly: **A. Approve** *(recommended)* — the cycle continues into planning; **B. Change** — say what to merge, split, add, drop, or reorder; **C. No pauses for this PRD** — build end to end, keep the ladder as a progress map. *No default — this waits for you.* (A new ladder is a decision with options that nothing lower decides; a changed ladder re-enters the same way, with the diff in its context lines.)

2. **Present the plan in the session**, in the project's working language, derived from `system.md` — never a second copy with different content:

   > **Checkpoint plan for <prd-NNN-slug>.** Architecture review is done. No code has been written. These are the points where the loop will pause for you. Each pause ends when you say `continue` or run `/loop $dev-cycle`.
   >
   > <for each new, changed, or reopened load-bearing decision, a brief built from system.md: **D-n — <decision>** · what it is, in the product's terms · considerations (its Why and Rejected) · unsure of (§11 risks citing it) · what rests on it, and for a change to built work, what has to change, including stored data to migrate · how it will be proven (its validation rung's samples)>
   >
   > <the ladder table from system.md — columns: #, Checkpoint, Kind, What you can do at the pause (its Poke), What the loop verifies first (its Verify)>
   >
   > **Why this cut:** <tl's rationale>. Expected: <tl's cycle estimate>.
   >
   > (On a re-presentation: **Changed since you approved (R-NNN):** <diff>.)
   >
   > **Your call (R-NNN):** A. Approve · B. Change · C. No pauses for this PRD. No default.

3. **Ask** with `AskUserQuestion` (options A/B/C; the owner can always type free text).
   - **A** → transcribe; mark `C1` reached in the loop-state Checkpoints section; close the entry as a durable ruling (`docs/rulings.md`, `Scope: prd-NNN`, Ruling: "checkpoint ladder approved as of <commit>"); write `Approval: R-NNN (<date>)` on the ladder in `system.md`. Continue to Phase 2 **in this same run**.
   - **B** → take the owner's words, spawn `tl` to amend the design or ladder accordingly, then re-present from step 2. Iterate until A or C.
   - **C** → close as a durable ruling (`Scope: prd-NNN`, Ruling: "no checkpoint pauses; the ladder is a progress map"); write `Approval: run-through R-NNN` in `system.md`; continue to Phase 2 in run-through mode.
   - **Declined or unanswered** (nobody is there) → the entry stays open. Write `docs/loop-state.md` with status `checkpoint` and `Pause: plan-review (R-NNN)`, run Checkpoint B, and stop with the plan as the exit report. The next cycle's Setup sweep finds the answer — written under "your answer" or said in chat — and resumes from the matching branch above.

A ladder tl changed in a later cycle (its Phase 1 return says "changed") re-runs this phase with the diff — unless the cycle is in run-through mode, in which case the change goes in the exit report and the review waits for the next attended cycle.

---

## Phase 2: Task Planning

**Sample request first.** If the active rung's Poke says `you supply:` and the sample path its Verify names is missing or empty, don't plan: set status `checkpoint` with `Pause: samples Cn`, run Checkpoint B, and stop with the sample request (Exit Conditions). Run-through does not skip this.

Spawn a `planner` subagent:

```
Prompt: "Based on the current project state, update docs/tasks.md with
the next round of tasks. Read docs/prd/index.md and active PRDs under
docs/prd/, all files under docs/design/, docs/status.md, docs/qa-report.md
(if it exists — every MEDIUM-or-higher bug except the deferred ones
below must become a fix task with priority above new feature work), and docs/eng-backlog.md (if it exists —
open engineering tasks). Prioritize in this order:
1. Fix MEDIUM-or-higher bugs from docs/qa-report.md (any kind — BUG,
   REGRESSION, FABRICATION, FLAKY, VISUAL_DEVIATION), and the routed
   defects listed below. Severity drives priority, not kind: a
   [LOW][FABRICATION] is lower than a [HIGH][BUG].
2. `blocking` ENG entries from docs/eng-backlog.md.
3. The highest-value unfinished CUJs and P1 ENG entries, interleaved —
   sequenced by pm-review priorities, dependencies, and ENG Ordering
   constraints.
4. LOW bugs and P2 ENG entries as capacity allows.
Never schedule new feature work while any MEDIUM-or-higher bug remains
unresolved. Tasks derived from ENG entries must reference the ENG ID in
the title, copy the entry's Verify check into 'Done when', and honor
Ordering constraints when grouping. Tasks fixing a routed defect must
carry its Issue ID in the title.

Routed defects (confirmed by triage; they need the full pipeline):
[embed each routed issue's ID, headline, CUJ, root cause, files, and
Notes — or 'none'].

Deferred bugs (count as LOW; a later validation rung's work — do not
schedule): [list, or 'none'].

Checkpoint ladder: the active rung is [Cn — title; Kind: seam | journey;
Scope: <...> — or 'no ladder']. Plan only the work needed to reach it
(tiers 1–2 still come first). For a seam rung, its poke action is part
of the rung's work.

Return a summary of what tasks were scheduled and how many parallel groups
there are."
```

If planner reports nothing left to do (all CUJs in scope implemented and tests passing), proceed to Phase 6 (PM Review) instead.

---

## Checkpoint A: Commit Before Spawning Coders

Coder worktrees branch from the last commit — anything uncommitted in this checkout (a fresh PRD, this cycle's design-doc updates, qa's new tests) is invisible to them. Run this checkpoint before **every** Phase 3 spawn: the first pass and each QA-retry pass.

**Commit discipline** (here and in Checkpoint B): subagents in the shared checkout never commit — tl's Phase 3.6 code fixes are the one exception. The orchestrator commits only at the two checkpoints, one typed commit per group below, passing only the listed paths that have changes (`git status --porcelain -- <paths>` lists them; skip a group when it's empty). Never `git add -A` or a bare `git commit` — the recipe keeps anything else staged in this checkout from riding along:

```bash
git add -- <paths> && git commit --only -m "<message>" -- <paths>
```

1. **Pending spec** — `docs/prd/ docs/ux/` → `docs(spec): commit pending spec changes before iter <N>`. Normally empty (`$design-feature` commits its own output); when it isn't — a hand edit, an older session — starting the loop means "build this spec," so commit it and list the files in the exit report.
2. **Plan** — `docs/design/ docs/eng-backlog.md docs/tasks.md docs/owner-queue.md docs/rulings.md scripts/owner-lint.sh` → `docs(cycle): iter <N> plan`.
3. **QA's tests** (retry passes only) — the files under qa-report.md's "New Tests Written", plus any QA tooling it installed (`scripts/qa-*.sh`, `.gitignore`) → `test(qa): <summary>`. Fix-coders need qa's failing tests in their worktree to reproduce the bugs.

---

## Phase 3: Task Execution

Run Checkpoint A, then read `docs/tasks.md`. For each parallel group, spawn all tasks simultaneously as background worktree agents:
- `agent_type: "coder"` — every task-execution agent uses the `coder` role definition (see `~/.codex/agents/coder.toml`). Coders own implementation + unit tests + local verification + commit; they explicitly do not modify PRDs/design docs/task plans and do not write integration/E2E tests (those belong to qa).
- `isolation: "worktree"` — each agent gets its own branch
- `run_in_background: true` — parallel execution
- Each agent's prompt must be fully self-contained with task description, file paths, and acceptance criteria
- If any `docs/*-guidelines.md` files were discovered in Setup, each agent's prompt must include: "Read all docs/*-guidelines.md files before starting. Your code and process must comply with every rule in those documents."
- Each agent commits its work when done

**All agents in a group must be spawned in a single message.**

Wait for all agents in the group to complete before moving to the next group. If any agent fails, note the failure and continue with remaining groups — do not abort the cycle.

### Phase 3.5: Merge & Resolve Conflicts

After all groups complete:
1. Record the pre-merge commit: `PRE_MERGE=$(git rev-parse HEAD)`.
2. Merge each agent's branch into the main branch in group order (Group 1 first, then Group 2, etc.)
3. Within each group, merge in the order tasks appear in `docs/tasks.md`
4. If a merge conflict occurs:
   - Attempt automatic resolution for trivial conflicts (import additions, non-overlapping changes)
   - For non-trivial conflicts, note the conflict in loop-state.md and attempt resolution by reading both changes and combining them
5. **PRD guard.** Task branches must never touch `docs/prd/` — coders are read-only there, and the only sanctioned PRD edit in this whole cycle is pm's status flip in Phase 6. List offending files: `git diff --name-only "$PRE_MERGE" HEAD -- docs/prd/`. If anything is listed, strip exactly those files (substitute them for `<files>`):

   ```bash
   git restore --source="$PRE_MERGE" --staged --worktree -- <files>
   git commit --only -m "revert: strip PRD edits from task branches (coders are read-only on docs/prd/)" -- <files>
   ```

   `restore`, not `checkout`: `git checkout <base> -- <dir>` resets files that existed at the base but leaves files a branch *added*, so a planted PRD file would survive. Then identify which branch introduced the edit and log the violation + task name in `docs/loop-state.md` — spec drifting to match implementation is exactly what this pipeline exists to prevent.
6. After all merges, run the project's compilation/type-check command (e.g., `npx tsc --noEmit`, `cargo check`, `go build ./...`, `python -m py_compile`) to verify the combined code compiles. If it fails, fix compilation errors before proceeding.

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

For tasks in this iteration derived from docs/eng-backlog.md entries
(task titles carrying an ENG-NNN ID), run your engineering-task
verification: confirm the coder's reported Verify evidence (re-run the
check where cheap), remove completed ENG blocks from docs/eng-backlog.md,
and flag missing or failing evidence as a Critical Issue.

Fix simple, unambiguous issues directly (unused imports, type annotations,
hardcoded values → constants). For design-level issues, flag them but do
not modify the code.

Active checkpoint: [Cn — title; Verify: <...>; Poke: <...> — or 'none
(journey rung or no ladder)']. For a seam rung, run its Verify and
confirm the poke action works; report `Checkpoint Cn Verify: PASS |
FAIL — <evidence>` in your summary (Section 4, Checkpoint verification).

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

Execute ALL of your steps:
1. Run the full test suite and capture results
2. Map coverage to CUJ acceptance criteria from active PRDs under docs/prd/
3. Write missing integration/E2E tests for implemented features
4. Run all tests again
5. Perform MANDATORY manual verification — start the app and walk every CUJ
6. Execute the fabrication detection checklist on EVERY claimed feature
7. Write docs/qa-report.md with per-CUJ verdicts and the overall verdict —
   that verdict is the gate; this orchestrator acts on it mechanically.

Read docs/prd/index.md and active PRDs under docs/prd/ for the CUJ
acceptance criteria. If any docs/*-guidelines.md files exist, read them
for the definition of 'done' — apply it strictly.

Tasks derived from docs/eng-backlog.md entries (ENG-NNN in the title)
have no CUJ: exclude them from per-CUJ verification — their functional
gate is the entry's Verify check, confirmed in code review. Your
responsibility for them is regression coverage only: the full test suite
must still pass, and any CUJ breakage caused by eng work is a bug like
any other.

Checkpoint ladder: the active rung is [Cn — kind — or 'no ladder']. A
seam rung's Verify is confirmed by tl, not you; your job there is the
suite plus walking whichever in-scope CUJs are walkable under your
UNIMPLEMENTED rule. A journey rung's CUJs ([IDs]) must all be walked —
they are the rung's gate."
```

### After QA completes:

Read `docs/qa-report.md` and check the overall verdict plus bug severities; deferred bugs (Setup) count as LOW throughout this phase. The verdict alone doesn't decide the loop — combine it with the severity distribution. `UNIMPLEMENTED` CUJs never affect this phase: they're unfinished work for later iterations, not failures of this one.

First, **incomplete verification** — the verdict line names CUJs QA couldn't fully walk even after re-walking. Unless MEDIUM+ bugs already send the loop back (that retry re-verifies everything), re-spawn `qa` once for just those CUJs; it counts toward the 2-retry budget. Still incomplete → mark status `blocked` with QA's reason and stop. Never send coders to fix a CUJ with no known bug. Then apply:

- **`PASS`** (no bugs): Continue to Phase 5.
- **`FAIL` with only `LOW` bugs across the entire report**: Continue to Phase 5. The LOW bugs carry forward in `docs/qa-report.md`, where the next iteration's planner picks them up.
- **`FAIL` with any bug of severity `MEDIUM` or higher** (any kind — `BUG`, `REGRESSION`, `FABRICATION`, `FLAKY`, `VISUAL_DEVIATION`): **Do NOT continue to Phase 5.** Instead:
  1. Log the failures in `docs/loop-state.md`.
  2. Jump back to **Phase 2** (re-plan with fixes for qa-report.md's MEDIUM+ bugs as the priority).
  3. Re-execute **Phase 3** (fix the issues) — Checkpoint A runs first, committing qa's new tests so the fix-coders can run them.
  4. Re-execute **Phase 4** (re-verify).
  5. Maximum 2 QA retry loops per iteration. If still failing after 2 retries, mark status as `blocked` with QA details and stop.
- **`BLOCKED`** (any CUJ Result is BLOCKED): Stop the loop, mark status as `blocked` in `docs/loop-state.md`, and surface the missing capability to the user. Do not retry — retries cannot fix a missing tool.

This inner loop ensures non-trivial bugs (MEDIUM+) are fixed within the same iteration, while LOW cosmetic issues flow forward without spinning the loop.

### Quality-surface smoke check (runs alongside the QA gate)

If `docs/quality/` exists: check whether any task merged this iteration touched files named in a `docs/quality/*/qspec.md` Surface section. For each affected slug, spawn an `evaluator` subagent for a **smoke** run (the fixed subset in `evalset/smoke.txt` — cheap, not a ledger entry). The evaluator is the only one who scores it; coders only proved the pipeline still runs. A regression beyond the noise floor on any dimension counts as a `[MEDIUM][REGRESSION]` bug in this phase's loop rules — the fix task is "restore quality on <slug> (see smoke diff)" or an explicit revert of the offending change. Smoke results are advisory breadth, not depth: improving quality is `$quality-cycle`'s job; this check only stops dev work from silently degrading it.

---

## Phase 5: Status Update

Spawn a `reporter` subagent:

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

**Seam-rung cycles**: skip this phase when the active rung is a seam rung and `docs/qa-report.md` shows no in-scope CUJ walked (every CUJ `UNIMPLEMENTED`) — there is no product evidence to judge. Otherwise run it as below.

Spawn a `pm` subagent:

```
Prompt: "Execute Section 6 (Review implemented work) of your role
definition. Judge every in-scope CUJ against the implementation
evidence — docs/qa-report.md, QA's walk screenshots under
docs/qa-artifacts/ (view them with the Read tool), and the code;
produce a product-side judgment per CUJ; write docs/pm-review.md
following the structure in your role definition.

Engineering tasks (ENG-NNN, from docs/eng-backlog.md) are out of scope
for your review — they have no product intent to judge. Review CUJs only.

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

If a prior phase already set status to `blocked` or `checkpoint` (Mocks Check pause, the Phase 1.5 plan review left open, QA `BLOCKED`, or Phase 4 retry budget exhausted), use that status and skip the computation. Otherwise compute the verdict deterministically from **both** the QA report and PM's review — no agent call needed:

- **`done`** if QA verdict is `PASS` (or `FAIL` with LOW-only bugs) AND **every in-scope CUJ has PM verdict `Satisfied`** in `docs/pm-review.md` AND **no `blocking` ENG entry remains open** in `docs/eng-backlog.md` (in scoped mode, count only blocking entries whose `Relates-to` names the target PRD) AND **no routed issue remains open** (after this phase's closing step below). All gates must pass. Open `P1`/`P2` ENG entries do NOT block `done` — they persist in the backlog for future cycles; that's what the backlog is for.
- **`continue`** otherwise — QA found MEDIUM+ bugs (and the Phase 4 inner loop didn't already exit), or PM judged at least one CUJ `Caveats` or `Not done`, or a `blocking` ENG entry or a routed issue is still open. The PM review's "Recommended Next-Iteration Priorities" list seeds the next planner.

This two-key gate ensures engineering correctness (QA) and product intent (PM) both sign off before the loop terminates. QA can pass a CUJ that meets every literal acceptance criterion while PM correctly judges it `Caveats` because the impl misses the point of the feature — that's a `continue` signal, not a `done`.

**Checkpoint rungs** (when a ladder exists). Before settling on `done`/`continue`, decide whether the **active rung** is reached:
- **seam** — tl's Phase 3.6 summary says `Checkpoint Cn Verify: PASS`, and QA's verdict is `PASS` or `FAIL` with LOW-only bugs (deferred bugs count as LOW).
- **journey** — every CUJ in the rung's Scope has QA `PASS` and PM `Satisfied` (the `done` gate, scoped to the rung).

Not reached → `continue` (the next planner keeps the same active rung). Reached → record it in the loop-state Checkpoints section (`Cn reached — iter N, <timestamp>`), then:
- it is the last rung → fall through to the `done` computation above (which also requires no `blocking` ENG entry and no open routed issue);
- a later rung exists and run-through does **not** cover this rung (no `--until` naming a later rung or `done`, no no-pauses ruling for its PRD) → status **`checkpoint`**, `Pause: Cn`;
- otherwise → mark it `reached (passed through)` and status `continue`.

A rung pause or a sample request is not an owner-queue entry — its only answer is running the loop again (after supplying the samples). The plan review in Phase 1.5 is the one queue-bearing pause.

**Close routed issues** whose fix is confirmed — its task merged and `docs/qa-report.md` shows the issue's CUJ `PASS` (CUJ `unknown` → merged and QA reports no related bug). Delete each closed block from `docs/issues.md`, along with the files its Screenshots field lists. Unconfirmed ones stay open for the next cycle.

Then write `docs/loop-state.md`. The `Last updated` stamp uses local time in the format `YYYY-MM-DD HH:MM:SS (UTC±N)` (e.g., `2026-05-02 14:23:45 (UTC+8)`) — day-precision is insufficient because the loop can rewrite this file multiple times per day during inner retries. Get the current timestamp via `python3 -c "from datetime import datetime as d; t=d.now().astimezone(); m=int(t.utcoffset().total_seconds()//60); s='+' if m>=0 else '-'; h,mm=divmod(abs(m),60); o=f'{h}:{mm:02d}' if mm else str(h); print(t.strftime('%Y-%m-%d %H:%M:%S')+f' (UTC{s}{o})')"`.

```markdown
# Dev Loop State

Last updated: <timestamp>
Iteration: <N>
Status: <continue | done | blocked | checkpoint>

## Last Cycle Summary
- Tasks executed: <count>
- CUJs passed QA: <count> of <in-scope count> (<u> unimplemented)
- Tests passing: <count>
- Tests failing: <count>
- QA inner loops used: <0-2>
- CUJs completed this cycle: <list>
- CUJs remaining: <count>
- ENG entries completed this cycle: <list of ENG-NNN, or "none">
- ENG entries open: <count> (<count of blocking>)
- Routed issues: taken <IDs, or "none"> / closed <IDs> / still open <count>

## QA Gate
- Verdict: <PASS | FAIL | BLOCKED>
- Fabrications found: <count> (<brief list or "none">)
- Bugs by severity: <CRITICAL n / HIGH n / MEDIUM n / LOW n>

## Checkpoints (if a ladder exists)
- Ladder approval: pending | R-NNN | run-through R-NNN
- Reached: C1 (iter 1, <timestamp>), C2 (iter 2, <timestamp>, passed through), ...
- Active rung: <Cn — title> (seam | journey)
- Pause: none | plan-review (R-NNN) | Cn | samples Cn   ← set when status = checkpoint
- Run-through: none | --until done | --until Cn | ruling R-NNN

## Blocker (if status = blocked)
<description of what requires user input — cite the docs/owner-queue.md
entry (R-NNN); a blocked status without a registered entry is an
owner-lint RED>

## Next Focus
<what the next iteration should prioritize — include unresolved QA items.
Planner-facing: owner decisions never park here; they live as R-NNN
queue entries>
```

---

## Checkpoint B: Commit the Iteration Record

Runs at **every** stop — `done`, `continue`, `checkpoint`, and every early `blocked` (Mocks Check pause, a `BLOCKER:` return from any phase, QA `BLOCKED`, retry budget exhausted) — after `docs/loop-state.md` is written and before the exit report. Same discipline and recipe as Checkpoint A:

1. **QA's tests** not yet committed → `test(qa): <summary>` (as in Checkpoint A group 3).
2. **The record** — every Checkpoint A path, plus `docs/loop-state.md docs/qa-report.md docs/pm-review.md docs/status.md docs/issues.md` → `docs(cycle): iter <N> — <status>`.

`docs/loop-state.md` is in this commit on every stop, so its last commit marks the end of the previous cycle — the baseline Setup uses for `CHANGED_PRDS` and bare `$spec-sync` uses for its delta.

---

## Exit Conditions

Every stop runs Checkpoint B before its report — including early `blocked` stops from any phase.

`/loop $dev-cycle` runs until the next pause — `checkpoint`, `done`, or `blocked` — unless `--until` says otherwise. A bare `$dev-cycle` is one iteration.

- **Status = `done`**: Report to the user that all CUJs in scope are implemented and verified by QA. List what was accomplished across all iterations. Stop the loop.
- **Status = `blocked`**: Report the blocker clearly to the user. Stop the loop and wait for their input.
- **Status = `checkpoint`**: Stop the loop — the owner asked to look here. Report per the pause kind:
  - **plan-review**: the plan presentation from Phase 1.5 (the ladder table, why this cut, the R-NNN and its options).
  - **samples `Cn`**: the sample request, in tl's voice — the decision the rung proves and what tl is unsure of (its §11 risks); each sample to supply with its expected outcome, verbatim from the Poke; where they go (the path its Verify names). Then: *Supply them, then reply `continue`.*
  - **rung `Cn`**: a try-it card — what exists now (the rung's title and Scope); how to start it (the project's canonical start command, e.g. `./scripts/qa-server.sh start`, and the entry URL); the rung's Poke actions verbatim; test counts and tl's Verify evidence; for a journey rung, the CUJ list with mock paths, QA's walk-screenshot paths, and PM's per-CUJ verdicts; and the next rung's title. Then the fixed closing line: *Reply `continue` to run to the next pause (`/loop $dev-cycle`), or `$dev-cycle` for a single iteration. Spec change → `$design-feature` (Route D). Defect → `$report-bug`. Design change → tell tl or edit `docs/design/`, then continue.*
- **Status = `continue`**: Report the iteration summary (tasks done, QA verdict, test results, routed issues taken / closed, what remains). The loop continues to the next iteration.

Every exit report — all four statuses, and the eng-wave net line — ends with the owner-queue line from the Setup sweep: `Owner queue: +<n> filed / <m> closed (<k> defaulted) / <j> open (oldest R-NNN, <i> iters)`.

## Codex adaptations

**Phase 3 on Codex.** Subagents share this checkout and sandbox; there is no per-agent worktree isolation. Reproduce it:

1. Once per cycle: `mkdir -p .worktrees`, and make sure `.worktrees/` is listed in `.gitignore` (commit that line if you add it, before Checkpoint A).
2. For each task in the group, in this same turn: `git worktree add .worktrees/<branch> -b <branch> HEAD`, then `spawn_agent(agent_type="coder", task_name="<worktree-label>: <task id>", message=<the self-contained task prompt> + "Work only inside `.worktrees/<branch>`: run every command with that directory as the working directory, commit there, and end your reply with the branch name and commit hash.")`.
3. `wait_agent` on all of them. A coder's final message is its return summary; `BLOCKER:` handling is unchanged.
4. Phase 3.5 merges the reported branches exactly as written, then `git worktree remove .worktrees/<branch>` (`--force` for a rejected branch) and deletes the branch.

If the sandbox refuses `git worktree add`, fall back to running the group's tasks sequentially in this checkout — one coder at a time, each committing before the next starts — and say so in the exit report.

**Owner questions.** Every `AskUserQuestion` step (Mocks Check, Phase 1.5): register the queue entry as written, then print the question with its options as your final message and end the turn, leaving `docs/loop-state.md` in the state the text prescribes for "unanswered" (`blocked` for the Mocks Check, `checkpoint` with `Pause: plan-review` for the plan review). The next `$dev-cycle` run's Setup sweep reads the answer.

**`/loop`.** Codex has no loop primitive. "`/loop $dev-cycle`" means: after a `continue` status, run this skill again in the same turn, until the status is `checkpoint`, `done`, or `blocked`, or the `--until` target is reached.
