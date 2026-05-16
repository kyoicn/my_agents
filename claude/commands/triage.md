---
description: Diagnose reported issues, assess scope, identify root cause, and recommend a resolution path (quick-fix vs. dev-cycle). Reads from docs/issues.md or takes a direct issue description.
---

# Triage

You are diagnosing reported issues to determine their root cause, scope, and the best resolution path. You do NOT fix anything — you analyze and recommend.

## Input

Check how you were invoked:
- **With a direct description** (e.g., `triage "articles aren't sorted by date"`): Diagnose that single issue.
- **Without arguments**: Read `docs/issues.md` and diagnose all open entries.

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

**b) Map to requirements**
- Find which CUJ(s) this issue relates to
- Determine: is this a deviation from an existing spec, or is the spec itself missing/incomplete?

**c) Identify root cause**
- Pinpoint the exact cause (wrong logic, missing case, stale data, race condition, etc.)
- Distinguish between the symptom and the underlying cause

**d) Assess scope**

Classify as one of three scopes:

| Scope | Criteria | Resolution path |
|-------|----------|-----------------|
| **small** | 1-3 files, no design change, clear spec deviation, isolated fix | `/quick-fix` |
| **medium** | Multiple files but no design change, may need QA verification | `/quick-fix` (with QA follow-up) |
| **large** | Cross-component, design implications, needs architectural review | `/dev-cycle` |

Key questions for scope assessment:
- How many files need to change?
- Does the fix require changing any interfaces, data models, or APIs?
- Could the fix break other features?
- Does it reveal a design flaw that needs rethinking?
- Is the existing spec sufficient, or does the PRD need updating?

### 3. Output diagnosis

For each issue, print a structured diagnosis:

```
## Issue: <one-line summary>

**Scope**: small | medium | large
**Related CUJ**: CUJ-<ID> (<PRD file>)
**Root cause**: <specific explanation — file:line, what's wrong, why>
**Files involved**: <list of files that need changes>
**Recommended action**: /quick-fix | /quick-fix + QA | /dev-cycle
**Risk**: <what could go wrong with the fix, regression potential>
```

For large-scope issues, additionally explain:
- What design decisions are affected
- Why `/quick-fix` is insufficient
- What the dev-cycle should focus on

### 4. Update docs/issues.md

After diagnosing, update each entry in `docs/issues.md` with the triage result. Change from raw description to triaged format:

Before:
```
- Sort order wrong on articles list
```

After:
```
- Sort order wrong on articles list — **small** — CUJ-003 (prd-000) — `src/services/articles.ts:42`
```

Keep it one line per issue. The detail is in the diagnosis output, not in the file.

If an issue from `docs/issues.md` turns out to be invalid (not a bug, works as designed, can't reproduce), remove it from the file and explain why in the output.

## What NOT to do

- Don't fix anything — only diagnose and recommend
- Don't modify source code, tests, or implementation files
- Don't modify PRD files or design docs
- Don't create tasks in docs/tasks.md
- Don't guess at root causes without reading the actual code
- Don't classify everything as "large" to be safe — be honest about scope
