---
name: "quick-fix"
description: "Fix a small-scope issue directly. Triages first (if not already triaged), then implements the fix, runs tests, and commits. For large issues, escalates to /dev-cycle."
---

# quick-fix

Use this skill when the user asks to run `quick-fix`.

## Command Template

# Quick Fix

You are fixing a small-scope issue — a clear bug, spec deviation, or defect that can be resolved in 1-3 files without design changes.

## Input

Check how you were invoked:
- **With a direct description** (e.g., `quick-fix "articles aren't sorted by date"`): Triage and fix that issue.
- **With a pre-triaged issue** (e.g., `quick-fix ISS-001` or context from a prior `/triage` run): Skip to fix using the existing diagnosis.
- **Without arguments**: Read `docs/issues.md`, pick the first triaged small/medium-scope entry, and fix it.

## Process

### 1. Triage (if not already done)

If the issue hasn't been triaged yet:
- Read the relevant source code and CUJs
- Identify root cause, files involved, and scope
- If scope is **large**: STOP. Tell the user: "This issue has design implications — recommend using `/dev-cycle` instead." Explain why. Do not attempt the fix.

If the issue was already triaged (from a prior `/triage` run or from a triaged entry in `docs/issues.md`), use that diagnosis but quickly verify it's still accurate by reading the relevant code.

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

### 6. Commit

Commit with a conventional commit message:
```
fix: <concise description>

Refs CUJ-<ID> (<prd-file>)
<one-line explanation of root cause and what was changed>
```

### 7. Update docs/issues.md

If the issue came from `docs/issues.md`, remove the entry. The fix is recorded in git history — the inbox doesn't need to track resolved items.

## Scope guard

If at any point during the fix you realize the issue is larger than expected:
- **You've already touched 3+ files and there's more to do**: Stop. Tell the user the scope expanded and recommend `/dev-cycle`.
- **The fix requires changing a shared interface or data model**: Stop. This needs TL review.
- **Fixing this bug would break other features**: Stop. This needs the full pipeline.

Do not push through a large fix just because you started. It's better to stop early and escalate than to produce a half-fix.

## What NOT to do

- Don't attempt large fixes — escalate to `/dev-cycle`
- Don't refactor or "improve" code beyond what the fix requires
- Don't modify PRD files or design docs — the spec isn't wrong, the code is
- Don't skip running tests
- Don't commit without a test that covers the bug (unless it's a purely cosmetic fix)
- Don't leave stale entries in docs/issues.md after fixing
