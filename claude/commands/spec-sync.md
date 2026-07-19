---
description: Reconcile PRDs and mocks with intentional out-of-band changes — user-directed edits that changed user-visible behavior without going through /design-feature. Applies minimal, user-confirmed amendments to the exact contradicted lines. Docs-only; scoped by construction (never a whole-project audit unless --all, which is inventory-first). The canonical spec-sync procedure lives here; /quick-fix runs it automatically after each fix.
---

# spec-sync — Reconcile spec with intentional drift

You are serializing out-of-band user intent back into the spec. The document authority hierarchy is:

> **user intent > PRD > design docs > tasks.md**

A PRD is authoritative because it records what the user decided. When the user changes behavior directly — "make the button green" via `/quick-fix`, a hand edit, an ad-hoc chat request — that is a spec change delivered from the level *above* the PRD. The PRD lines and mocks asserting the old behavior are now stale and owe an amendment. This command pays that debt.

**What this command is NOT:** a redesign tool (journey-shape changes go to `/design-feature` Route D), a code tool (docs-only — it never edits implementation), or a verification tool (it checks statically-readable assertions; behavioral truth belongs to QA's browser walks in `/dev-cycle`).

## Scope — determined by invocation, never "everything" by default

| Invocation | Scope |
|---|---|
| `/spec-sync "<description>"` (e.g. `"save button is now green"`) | The described change → the CUJ(s) it plausibly touches → those CUJs' PRD sections + mocks. |
| `/spec-sync CUJ-<id>` | That CUJ's spec + mocks vs the current implementation of that journey's surface. |
| `/spec-sync <commit-range>` (e.g. `HEAD~3..`) | User-visible changes in that range → mapped CUJs → their sections + mocks. |
| `/spec-sync` (bare) | Changes since the last sync marker: `git log -n1 --format=%H -- docs/loop-state.md` (end of last cycle), else the last 10 commits. User-visible deltas only. |
| `/spec-sync --all` | **Inventory-first sweep** — see its own section below. Never run this scope without the inventory confirmation. |

A typical scoped run reads one diff, one PRD's relevant sections, and 1–3 mock files.

## The procedure (canonical — /quick-fix Step 6 runs these same steps scoped to its own change)

1. **Identify the delta.** Per the invocation mode: the described change, the CUJ's surface, or the commit range's diff. Filter to user-visible changes (UI, copy, output, observable behavior) — internal refactors carry no spec obligation.

2. **Map to spec assertions.** For each user-visible change, find what the spec currently asserts: grep the active PRDs for the affected CUJ's Journey Steps and Acceptance Criteria; glob `docs/ux/**/cuj-<id>-*.{html,png,jpg,webp,md}` for the mocks. Collect every line/token that the change contradicts.

3. **Confirm direction — one question per finding.** You are interactive (user-invoked); use it:
   > The spec says X (`prd-002` CUJ-3, criterion 4; `cuj-3-initial.html`). The code now does Y. Sync the spec to Y — or is the spec right and the code should revert?
   - **Sync** → step 4. **Revert** → this was an accidental spec violation, not drift: file it via `/report-bug` (or fix immediately if trivial and the user says so). Do not amend the spec.

4. **Amend minimally.** Only the contradicted lines: the criterion's phrase, the Journey Step's "User sees" clause, the mock's token (a Tailwind class, a copy string). For `.png`/`.jpg` mocks that can't be token-edited, note in the CUJ's Mocks section: `(color superseded — see criterion N; re-export pending)` rather than deleting the mock.
   - **Never**: add/remove/renumber CUJs, restructure Journey Steps, touch frontmatter `status`, edit design docs (tl reconciles those against the amended PRD next `/dev-cycle` Phase 1), or edit code.
   - If the amendment cannot stay minimal — the change alters the journey's *shape* (new states, different flow, removed steps) — **stop and route to `/design-feature` Route D**. That's a redesign wearing a sync's clothes.

5. **Commit docs-only**, with an auditable trailer:
   ```
   docs(spec-sync): align prd-002 CUJ-3 with green save button

   Spec-sync: prd-002-articles CUJ-3 criterion 4; journey step 2 "User sees"
   Spec-sync: docs/ux/prd-002-articles-mockups/cuj-3-initial.html (btn color token)
   Source: user-directed change (<commit sha or "this session">)
   ```

This is the **sole exception** to "pm is the only PRD writer": minimal amendments, to lines directly contradicted by a user-directed change, confirmed by the user in-session, recorded in the commit. Nothing broader.

## `--all` mode — inventory first, CUJ by CUJ, honest about limits

For one-time spec-debt cleanup (adopting the discipline late, or after a stretch of ad-hoc work). Not for routine use — routine is the scoped modes.

1. **Sweep and inventory before touching anything.** Walk active PRDs CUJ by CUJ; for each, check **statically-checkable assertions only** — copy strings, labels, colors, layout classes readable from mocks and component source. Build the drift inventory and print it with costs up front:
   > Found 23 checkable assertion mismatches across 9 CUJs (~15 files to read). 11 behavioral assertions can't be checked statically — listed at the end for the next QA walk. Proceed CUJ-by-CUJ?
2. **Get confirmation, then process per CUJ** using the procedure above — one sync-or-revert pass per CUJ, **one commit per CUJ** so a partial run is durable and resumable.
3. **Behavioral assertions are out of bounds.** Timing, network behavior, multi-step flows — anything requiring a running product — goes in a "needs QA walk" list at the end, never amended on guesswork. Do not fabricate verification.
4. **Know when to hand off.** If the inventory shows drift concentrated in journey *shapes* rather than tokens, say so and recommend the honest full-project tool instead: run `/dev-cycle` (QA walks every CUJ in a real browser and produces the authoritative deviation list), then scoped spec-syncs for the deviations the user declares intentional.

## What NOT to do

- Don't edit implementation code — docs-only, always.
- Don't edit design docs — tl reconciles them against the amended PRD in the next `/dev-cycle` Phase 1 (PRD is the baseline there).
- Don't add, remove, or restructure CUJs, and don't touch PRD frontmatter `status` — shape changes are `/design-feature` Route D; lifecycle is pm's.
- Don't amend without the user's sync-or-revert confirmation — the question is also the tripwire that catches accidental spec violations.
- Don't amend behavioral assertions you can't verify statically — route them to a QA walk.
- Don't run `--all` without printing the inventory and getting confirmation first.
- Don't batch multiple CUJs into one commit in `--all` mode — per-CUJ commits keep partial runs resumable.
