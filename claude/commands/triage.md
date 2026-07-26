---
description: Diagnose reported issues, assess scope, identify root cause, and recommend a resolution path (quick-fix vs. dev-cycle). Reads from docs/issues.md or takes a direct issue description.
---

# Triage

You are diagnosing reported issues to determine their root cause, scope, and the best resolution path. You do NOT fix anything — you analyze and recommend.

## Input

Check how you were invoked:
- **With an issue ID** (e.g., `triage 2026-06-03-14-30-25`): Read that specific h3 block from `docs/issues.md`, including its `Screenshots:` field if present, and diagnose only that issue.
- **With a direct description** (e.g., `triage "articles aren't sorted by date"`): Diagnose that ad-hoc description. Do NOT write anything back to `docs/issues.md` — there's no block to attach to. Just print the diagnosis.
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

| Scope | Criteria | Resolution path |
|-------|----------|-----------------|
| **small** | 1-3 files, no design change, clear spec deviation, isolated fix | `/quick-fix` |
| **medium** | Multiple files but no design change, may need QA verification | `/quick-fix` (with QA follow-up) |
| **large** | Cross-component, design implications, needs architectural review | `/dev-cycle` |
| **spec-gap** | Behavior not defined in any PRD, needs product design before code | `/design-feature` (Route C extend or Route D refine — let the orchestrator decide) |
| **spec-conflict** | Report contradicts the PRD spec — user must decide which is correct | ask user (spec wrong → `/design-feature` Route D to refine; report wrong → close as invalid) |
| **spec-stale** | Implementation deviates from the PRD *deliberately* — git history shows a user-directed change (e.g. a `fix:` commit from a /quick-fix or ad-hoc session) newer than the spec text. The code is right; the doc is stale. | `/spec-sync` (docs-only — amend the contradicted PRD lines/mocks; no code change) |
| **quality** | The deterministic behavior is correct, but *how good* the output is falls below bar — statistically or on a category ("summaries are bad on listicles"). Not a code defect, not a stale spec: a quality gap on a surface with (or needing) a qspec under `docs/quality/`. | `/quality-cycle <slug>` — and hand the complaint's example(s) to the evaluator as eval-set case candidates. No qspec exists yet → `/design-quality` first. Never "fix" quality by vibe in a quick-fix. |

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
**Recommended action**: /quick-fix | /quick-fix + QA | /dev-cycle | /design-feature | /spec-sync | /quality-cycle | ask user
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
  - **Recommended action**: `/quick-fix`
  - **Risk**: low — isolated to one comparator, no API change
```

Format rules:
- Triage timestamp uses the same format as the rest of the project: `YYYY-MM-DD HH:MM:SS (UTC±N)`. Get it via the standard `python3 -c "..."` one-liner used elsewhere.
- Append `Triage` at the bottom of the block, after the existing fields. Do not rewrite the headline; preserve it verbatim.
- If a `Triage` field already exists on a block (re-triage), replace the entire `Triage` block with the new one. Don't accumulate.
- If the issue turns out to be invalid (not a bug, works as designed, can't reproduce), remove the entire h3 block from `docs/issues.md` (including the leading `---` separator and any screenshots referenced in its Screenshots field — delete those files from `docs/issues-attachments/` too). Explain why in the diagnosis output.

The format on disk is structured for human + agent readability. The diagnosis printed to the conversation (Step 3) is for the user reading now; the field-block in the file is for `/quick-fix` (and the user) to consume later.

## What NOT to do

- Don't fix anything — only diagnose and recommend
- Don't modify source code, tests, or implementation files
- Don't modify PRD files or design docs
- Don't create tasks in docs/tasks.md
- Don't guess at root causes without reading the actual code
- Don't classify everything as "large" to be safe — be honest about scope
