---
name: triage
description: "Diagnose reported issues and route each to the command that fixes it — run-now routes (quick-fix, spec-sync, design-feature) execute in this session; queued routes (dev-cycle, quality-cycle, design-quality) are taken by that command's next run. Reads from docs/issues.md or takes a direct issue description."
---

<!-- generated-from: claude/commands — do not edit; regenerate with antigravity/skills/sync-from-claude -->

# triage

Use this skill when the user runs `/triage`.

> **Antigravity runtime notes** — this text was written for Claude Code; on Antigravity read it as follows.
> - Slash commands keep their names: `/dev-cycle` is the skill `dev-cycle`. `/loop /x` means: run `/x` again in this same turn after each stop that is not final, until it reports a stopping status (`checkpoint`, `done`, `blocked`, or the `--until` target).
> - "Spawn a `<role>` subagent" / `subagent_type: "<role>"` → `invoke_subagent` with the custom agent `<role>` and the full prompt as its initial message. The roles are the `~/.gemini/config/agents/*.md` agents: tl, planner, coder, qa, reporter, pm, evaluator, researcher, gorilla. Subagents run in the background and several may run at once; a subagent's result message is its return summary.
> - `isolation: "worktree"` → invoke that subagent with the `branch` workspace mode, which gives it an isolated git worktree; merge its branch exactly as the text says. "Spawn all in a single message" / `run_in_background: true` → invoke every one of them before waiting on any.
> - `AskUserQuestion` → do the registration the text asks for first, then put the question and its options in your reply and end the turn; the next run picks the answer up from the owner queue or the chat.
> - Claude tool names (Read, Grep, Glob, Edit, Write, Bash, WebSearch, WebFetch) are Antigravity's file, search, shell, and web tools (view_file, grep_search, list_dir, replace_file_content, write_to_file, run_command, search_web, read_url_content). Playwright MCP tools are Antigravity's built-in browser capability.
> - `~/.claude/agents/*.md` and `~/.claude/commands/*.md` are `~/.gemini/config/agents/*.md` and `~/.gemini/config/skills/*/SKILL.md`; `CLAUDE.md` is `GEMINI.md` (already rewritten).

## Command Template

# Triage

You are the router for reported issues: diagnose each one's root cause and scope, then hand it to the command that fixes it. Every issue leaves triage routed — never parked with a recommendation. You don't write fixes yourself; the receiving command does.

## Input

Check how you were invoked:
- **With an issue ID** (e.g., `triage 2026-06-03-14-30-25`): Read that specific h3 block from `docs/issues.md`, including its `Screenshots:` field if present, and diagnose only that issue.
- **With a direct description** (e.g., `triage "articles aren't sorted by date"`): Diagnose that ad-hoc description, then route it per Step 5 (which says when an ad-hoc item needs a block in `docs/issues.md`).
- **Without arguments**: Read `docs/issues.md` and diagnose every block that doesn't already have a `**Triage**:` field.

If `docs/issues.md` doesn't exist and no description was provided, tell the user there's nothing to triage.

## Process

### 1. Understand the project context

Quickly orient yourself:
- Read `docs/prd/index.md` and skim active PRDs for relevant CUJs
- Read `docs/design/system.md` for architecture context
- Read `docs/status.md` if it exists
- Check `docs/qa-report.md` if it exists — the issue may already be documented there

### 2. For each issue, diagnose

**a) Reproduce / Confirm the issue**
- Read the relevant source code
- Understand what the code currently does vs. what it should do
- Identify the specific file(s) and line(s) where the behavior originates
- If it's a runtime issue and a dev server can be started, start it and verify
- **If the issue block lists screenshots under `Screenshots:`, read each one with the Read tool** to incorporate the visual evidence into your diagnosis. A screenshot often pinpoints the layout/state where the bug manifests faster than re-reading the code.

**b) Map to requirements**
- Find which CUJ(s) this issue relates to
- Determine: is this a deviation from an existing spec, or is the spec itself missing/incomplete?

**c) Identify root cause**
- Pinpoint the exact cause (wrong logic, missing case, stale data, race condition, etc.)
- Distinguish between the symptom and the underlying cause

**d) Assess scope**

Classify as one of seven scopes:

| Scope | Criteria | Route (executed in Step 5) |
|-------|----------|-----------------|
| **small** | 1-3 files, no design change, clear spec deviation, isolated fix | `/quick-fix` — run now |
| **medium** | Multiple files but no design change, may need QA verification | `/quick-fix` — run now (the next `/dev-cycle`'s QA walk re-verifies) |
| **large** | Cross-component, design implications, needs architectural review — or the root cause lies in code a load-bearing decision owns (`system.md` §9's Load-bearing column): Notes name the D-ID, and tl reopens it | `queued → /dev-cycle` — its next run takes it |
| **spec-gap** | Behavior not defined in any PRD, needs product design before code | `/design-feature` — run now (Route C extend or Route D refine — let its orchestrator decide) |
| **spec-conflict** | Report contradicts the PRD spec — user must decide which is correct | ask the user now → spec wrong: `/design-feature` Route D; report wrong: close as invalid |
| **spec-stale** | Implementation deviates from the PRD *deliberately* — git history shows a user-directed change (e.g. a `fix:` commit from a /quick-fix or ad-hoc session) newer than the spec text. The code is right; the doc is stale. | `/spec-sync` — run now (docs-only — amend the contradicted PRD lines/mocks; no code change) |
| **quality** | The deterministic behavior is correct, but *how good* the output is falls below bar — statistically or on a category ("summaries are bad on listicles"). Not a code defect, not a stale spec: a quality gap on a surface with (or needing) a qspec under `docs/quality/`. | `queued → /quality-cycle <slug>` — its next run hands the complaint's example(s) to the evaluator as eval-case candidates. No qspec yet → `queued → /design-quality (<surface>)`. Never "fix" quality by vibe in a quick-fix. |

Key questions for scope assessment:
- How many files need to change?
- Does the fix require changing any interfaces, data models, or APIs?
- Could the fix break other features?
- Does it reveal a design flaw that needs rethinking?
- Is the existing spec sufficient, or does the PRD need updating?
- Is this actually a missing feature rather than a bug? If no CUJ defines the expected behavior, it's a spec-gap.
- Does the reported "expected behavior" directly contradict what the PRD specifies? If so, it's a spec-conflict — don't assume either side is correct.
- Does the implementation deviate from the PRD because someone *chose* that? Check `git log` on the files involved: a user-directed change (fix/feat commit, spec-sync trailer absent) newer than the PRD text means spec-stale — the fix is to the docs, not the code. Don't schedule a revert of intentional work.
- Is the complaint about one deterministic misbehavior (crashes, wrong sort, missing element → a defect) or about *how good* generated output is, in general or on a category (→ quality)? One bad summary from a correctly-running pipeline is a quality case candidate, not a bug — route it to the quality track and offer its example to the eval set.

**e) Check the track: is this actually an engineering task?**

If diagnosis reveals the report isn't a defect at all — nothing deviates from spec for a user; it's infrastructure, tooling, operational hardening, or tech debt (e.g., "the deploy pipeline has no rollback step" filed as a bug) — it's misfiled. Reclassify it:
1. File it as an `ENG-NNN` entry in `docs/eng-backlog.md` using the canonical schema from `/eng-task` (consume the `Next-ID:` counter; carry Background/Scope/Acceptance criteria from your diagnosis; **derive a concrete, executable `Verify` check** — an entry without one may not be filed; set Priority honestly).
2. Remove the issue's h3 block from `docs/issues.md` (and delete any files under `docs/issues-attachments/` its Screenshots field lists).
3. Tell the user what you did and why, citing the new ENG ID.

Separately: if diagnosing a *genuine* defect surfaces **adjacent tech debt that is not part of the fix** (the fix works without it, but the debt made the bug possible or will bite again), don't fold it into the fix's scope and don't lose it — file it as its own ENG entry with `Relates-to: Issue <id>`, and mention the ENG ID in your diagnosis. The defect keeps its own track.

### 3. Output diagnosis

For each issue, print a structured diagnosis:

```
## Issue: <one-line summary>

**Scope**: small | medium | large | spec-gap | spec-conflict | spec-stale | quality
**Related CUJ**: CUJ-<ID> (<PRD file>) | none (spec-gap)
**Root cause**: <specific explanation — file:line, what's wrong, why>
**Files involved**: <list of files that need changes>
**Route**: /quick-fix | /spec-sync | /design-feature | ask user | queued → /dev-cycle | queued → /quality-cycle <slug> | queued → /design-quality (<surface>)
**Risk**: <what could go wrong with the fix, regression potential>
```

For large-scope issues, additionally explain:
- What design decisions are affected
- Why `/quick-fix` is insufficient
- What the dev-cycle should focus on

For spec-gap issues, additionally explain:
- What behavior the user expects that no CUJ currently defines
- What questions PM needs to answer before implementation can start
- Whether this is a net-new feature, an extension of an existing CUJ, or a refinement of an existing CUJ — this maps to which `/design-feature` route the user should invoke (B/C/D respectively)

For spec-conflict issues, additionally explain:
- What the PRD specifies (quote the relevant CUJ step or acceptance criterion)
- What the report claims the behavior should be
- The current implementation (does it follow the PRD or not?)
- Do NOT decide which side is correct — present both and ask the user to resolve
- **Headless invocation** (orchestrated, no live user): don't leave "ask user" dangling — register the conflict as a `docs/owner-queue.md` entry per the Owner Decision Protocol (`dev-cycle.md` Setup), options = the two readings, no armed default (spec conflicts are the owner's), and cite the R-NNN in the Triage field's Route

### 4. Update docs/issues.md — append a Triage field to the issue block

Each issue in `docs/issues.md` is an h3 block (written by `/report-bug`). After diagnosing, **append a structured `Triage:` field to the bottom of the block**. Do NOT modify the block's existing fields (Description, CUJ, Expected, Observed, Repro, Screenshots) — those are the original report; preserve them.

Before:
```markdown
### Issue 2026-06-03-14-30-25: Sort order wrong on articles list

- **Filed**: 2026-06-03 14:30:25 (UTC+8)
- **Description**: Articles in /articles render in random order
- **CUJ**: CUJ-3 (prd-002-articles)
- **Expected**: Sorted by date descending
- **Observed**: Appears random
- **Repro**: 1. Open /articles. 2. Note order ≠ date desc.
- **Screenshots**:
  - docs/issues-attachments/2026-06-03-14-30-25-1.png
```

After:
```markdown
### Issue 2026-06-03-14-30-25: Sort order wrong on articles list

- **Filed**: 2026-06-03 14:30:25 (UTC+8)
- **Description**: Articles in /articles render in random order
- **CUJ**: CUJ-3 (prd-002-articles)
- **Expected**: Sorted by date descending
- **Observed**: Appears random
- **Repro**: 1. Open /articles. 2. Note order ≠ date desc.
- **Screenshots**:
  - docs/issues-attachments/2026-06-03-14-30-25-1.png
- **Triage** (2026-06-03 15:02:11 (UTC+8)):
  - **Scope**: small
  - **Root cause**: `src/services/articles.ts:42` — `sort()` callback returns 0 for all comparisons because timestamps are strings
  - **Files involved**: `src/services/articles.ts`
  - **Route**: `/quick-fix`
  - **Risk**: low — isolated to one comparator, no API change
```

Format rules:
- Triage timestamp uses the same format as the rest of the project: `YYYY-MM-DD HH:MM:SS (UTC±N)`. Get it via the standard `python3 -c "..."` one-liner used elsewhere.
- Append `Triage` at the bottom of the block, after the existing fields. Do not rewrite the headline; preserve it verbatim.
- For queued routes, the Triage field is all the receiving loop will see — add a `Notes` sub-field carrying Step 3's extra explanation (for large: design decisions affected, what the dev-cycle should focus on; for quality: which surface and category, which example to use).
- If a `Triage` field already exists on a block (re-triage), replace the entire `Triage` block with the new one. Don't accumulate.
- If the issue turns out to be invalid (not a bug, works as designed, can't reproduce), remove the entire h3 block from `docs/issues.md` (including the leading `---` separator and any screenshots referenced in its Screenshots field — delete those files from `docs/issues-attachments/` too). Explain why in the diagnosis output.

The format on disk is structured for human + agent readability. The diagnosis printed to the conversation (Step 3) is for the user reading now; the field-block in the file is the handoff record the receiving command consumes.

### 5. Route — hand each issue to its fixer

After printing all diagnoses and writing the Triage fields, work through the routes in inbox order:

- **Run-now routes** (`/quick-fix`, `/spec-sync`, `/design-feature`, and the spec-conflict question): invoke the command on the issue in this session. `/quick-fix` removes the issue block itself; for the others, remove the block (and the files its Screenshots field lists) once the command completes — its commit is the record. If a handoff doesn't complete (the user stops it, or the command re-routes), the block stays with its Route recorded.
- **Queued routes** (`queued → /dev-cycle`, `queued → /quality-cycle <slug>`, `queued → /design-quality (<surface>)`): don't start the loop — those are long runs on the user's cadence. The Route field *is* the handoff: that command takes every issue queued for it on its next run, reports what it took, and removes the block once the fix (or eval case) is in. Tell the user where each went ("queued for your next `/dev-cycle`").
- **Ad-hoc descriptions** (no block): run-now routes run on the description directly. A queued route needs a block for the loop to take — append one to `docs/issues.md` in `/report-bug`'s format (the description plus your Triage field), so nothing routed is lost.
- **Headless** (no live user): record the routes and run nothing; spec-conflicts register in the owner queue per Step 3.

## What NOT to do

- Don't write fixes yourself — route to the command that fixes (Step 5)
- Don't modify source code, tests, or implementation files
- Don't modify PRD files or design docs
- Don't create tasks in docs/tasks.md
- Don't guess at root causes without reading the actual code
- Don't classify everything as "large" to be safe — be honest about scope
