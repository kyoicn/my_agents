---
description: Fix a small-scope work item directly — a defect from docs/issues.md, an ad-hoc description, or a small engineering task from docs/eng-backlog.md (quick-fix ENG-NNN). Triages first (if not already triaged), then implements, runs tests, and commits. For large issues, escalates to /dev-cycle; ENG entries with Ordering constraints always go through the planner.
---

# Quick Fix

You are fixing a small-scope work item — a clear bug, spec deviation, or defect that can be resolved in 1-3 files without design changes, or a small engineering task from `docs/eng-backlog.md` with the same profile.

## Input

Check how you were invoked:
- **With an issue ID** (e.g., `quick-fix 2026-06-03-14-30-25`): Read that specific h3 block from `docs/issues.md` and fix it. If the block has a `Triage` field, use it as the diagnosis (verify against current code quickly). If not, run the triage logic from `/triage` inline first.
- **With an ENG ID** (e.g., `quick-fix ENG-004`): Read that h3 block from `docs/eng-backlog.md`. The entry's Scope/Acceptance criteria/Verify fields are the spec — no triage needed. Two eligibility gates before touching code:
  - The entry must pass the same small-scope gate as a defect (1-3 files, no design change, no shared interface or data-model change). Larger → STOP, tell the user it goes through the planner (`/dev-cycle` or `/user:planner`).
  - The entry must have **no `Ordering` field**. Ordering constraints are honored by the planner's group sequencing; ad-hoc execution loses them. Constrained → STOP, same redirect.
- **With a direct description** (e.g., `quick-fix "articles aren't sorted by date"`): Triage and fix that ad-hoc description in one shot, without going through `docs/issues.md`.
- **Without arguments**: Read `docs/issues.md`, pick the first **triaged** small/medium-scope block (one whose `Triage` field shows scope=small or scope=medium), and fix it.

**The scope gate applies regardless of where the diagnosis came from** — an existing `Triage` field, your inline triage, or an ENG entry's fields. If the (existing or freshly derived) scope is large, spec-gap, or spec-conflict, STOP and escalate per Step 1; never proceed because a diagnosis already exists.

## Process

### 1. Triage (if not already done)

If the issue block already has a `Triage` field (because `/triage` ran on it), use that as the diagnosis but verify it's still accurate by quickly reading the relevant code.

If the issue hasn't been triaged yet:
- Read the relevant source code and CUJs
- **If the block has a `Screenshots` field, read each screenshot with the Read tool** for visual context before diagnosing.
- Identify root cause, files involved, and scope
- If scope is **large**: STOP. Tell the user: "This issue has design implications — recommend using `/dev-cycle` instead." Explain why. Do not attempt the fix.
- If scope is **spec-gap** or **spec-conflict**: STOP. Recommend `/design-feature` (Route C or D) and explain.

### 2. Plan the fix

Before writing any code:
- State what you're going to change and why
- Identify which tests already cover this behavior (if any)
- Identify whether a new test is needed to prevent regression

### 3. Implement the fix

- Make the minimal change needed to resolve the issue
- Do not refactor surrounding code
- Do not add features
- Do not change interfaces or APIs unless that's the actual bug
- Follow existing code conventions and patterns

### 4. Test

- Run the project's existing test suite — all tests must still pass
- If the bug wasn't covered by an existing test, write a focused test that:
  - Reproduces the original bug (would have failed before the fix)
  - Verifies the correct behavior (passes after the fix)
  - Name it clearly: reference the CUJ and the specific behavior
- Run tests again with the new test included

### 5. Verify

If a dev server can be started and the fix is UI-visible or API-observable:
- Start the dev server
- Manually verify the fix works as expected
- Check that adjacent functionality isn't broken

**For an ENG entry, additionally execute the entry's `Verify` check exactly as written** and confirm the expected outcome. Report the command and its output to the user — that evidence is the entry's done-gate. If the check fails, the task is not done; do not proceed to commit.

### 6. Commit

Commit with a conventional commit message:
```
fix: <concise description>

Refs CUJ-<ID> (<prd-file>)
<one-line explanation of root cause and what was changed>
```

For an ENG entry, reference the ENG ID instead (this is the permanent record once the block is removed):
```
<type>: <concise description> (ENG-NNN)

<one-line explanation of what was done and the Verify outcome>
```

### 7. Clean up the issue + its attachments

If the issue came from `docs/issues.md`:

1. Locate the issue's h3 block in `docs/issues.md`. Note any files listed under its `Screenshots:` field.
2. **Delete those screenshot files** from `docs/issues-attachments/`. They were transient evidence; the fix is in git, the screenshots are no longer needed.
3. **Remove the entire h3 block** from `docs/issues.md`, including the leading `---` separator. Be careful not to remove an adjacent issue's separator.
4. If `docs/issues.md` is now empty (just the preamble), leave the preamble in place — don't delete the file.

The fix is recorded in git history — the inbox doesn't need to track resolved items, and the attachments dir stays clean.

If the issue came from a direct `quick-fix "<description>"` invocation (no block in `docs/issues.md`), there's nothing to clean up — the git commit is the only record.

If the work item was an ENG entry: remove its h3 block from `docs/eng-backlog.md` (including the leading `---` separator; leave the preamble and `Next-ID:` line untouched). There are no screenshots to delete.

## Scope guard

If at any point during the fix you realize the issue is larger than expected:
- **You've already touched 3+ files and there's more to do**: Stop. Tell the user the scope expanded and recommend `/dev-cycle`.
- **The fix requires changing a shared interface or data model**: Stop. This needs TL review.
- **Fixing this bug would break other features**: Stop. This needs the full pipeline.

Do not push through a large fix just because you started. It's better to stop early and escalate than to produce a half-fix.

## What NOT to do

- Don't attempt large fixes — escalate to `/dev-cycle`
- Don't fast-path an ENG entry that has an `Ordering` field — constrained entries go through the planner, whatever their size
- Don't complete an ENG entry without executing its `Verify` check and reporting the evidence
- Don't refactor or "improve" code beyond what the fix requires
- Don't modify PRD files or design docs — the spec isn't wrong, the code is
- Don't skip running tests
- Don't commit without a test that covers the bug (unless it's a purely cosmetic fix)
- Don't leave stale entries in docs/issues.md after fixing
- Don't leave orphaned screenshots in docs/issues-attachments/ — Step 7 deletes them along with the issue block
- Don't commit screenshots from docs/issues-attachments/ — the directory should already be in .gitignore (created by /report-bug); never bypass that
