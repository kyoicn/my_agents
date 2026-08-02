---
description: File an engineering task into docs/eng-backlog.md — infrastructure, tooling, operational hardening, tech debt. Neither a defect (that's /report-bug) nor a product feature (that's /design-feature). Every entry requires a mechanically executable Verify check at intake. Optionally fast-paths small, unconstrained entries straight to /quick-fix.
---

# eng-task — File an engineering task into the backlog

You are filing an engineering task. The output is one h3-block entry in `docs/eng-backlog.md`.

This skill owns **intake only**. Prioritization is the planner's job (the backlog is a first-class planner input alongside PRDs and `docs/qa-report.md`); execution is `/quick-fix ENG-NNN` for small entries or the planner → coder pipeline for everything else; the done-gate is tl's code review confirming the entry's Verify evidence. **Dispatch is owner-carried by default** — batches drain via `/dev-cycle eng` waves (one command per wave, never one per ticket); orchestrators may auto-dispatch only under a standing authorization recorded as a ruling in the relevant `rulings.md`.

## Which track? — the classification rule (canonical)

Before filing anything, confirm this is actually an engineering task:

> **Does the product deviate from its spec for a user today?** → defect — use `/report-bug` (`docs/issues.md`). **Does it change what the product does for users** (has a product surface, needs a design conversation)? → feature — use `/design-feature` (`docs/prd/`). **Everything else that changes code, infrastructure, tooling, or process** — compatibility shims, deploy pipelines, metrics groundwork, persistence hardening, tech debt — is an engineering task and belongs in `docs/eng-backlog.md`.
>
> Hybrid cases split at the boundary: a defect whose fix reveals tech debt keeps the fix as the defect and files the debt as a linked ENG entry; a feature with infrastructure prerequisites gets ENG entries linked from the PRD (`Relates-to`), scheduled ahead of it.

If the description sounds like a defect or a feature, say so and redirect the user to the right command — do not file it here.

## Phase 0: Setup

1. If `docs/eng-backlog.md` does not exist, create it with this preamble:

   ```markdown
   # Engineering Backlog

   Engineering tasks: infrastructure, tooling, operational hardening, tech debt — work that is neither a defect (docs/issues.md) nor a product feature (docs/prd/). Entries are removed when done; history lives in git via commits referencing the ENG ID.

   Next-ID: ENG-001

   ---
   ```

2. Take this entry's ID from the `Next-ID:` line, then increment that line (e.g., consume `ENG-004`, rewrite the line to `Next-ID: ENG-005`). The counter exists so IDs are never reused after completed entries are deleted — don't derive IDs by scanning existing blocks.

3. Generate the filed timestamp in the project-standard format `YYYY-MM-DD HH:MM:SS (UTC±N)`:
   ```bash
   python3 -c "from datetime import datetime as d; t=d.now().astimezone(); m=int(t.utcoffset().total_seconds()//60); s='+' if m>=0 else '-'; h,mm=divmod(abs(m),60); o=f'{h}:{mm:02d}' if mm else str(h); print(t.strftime('%Y-%m-%d %H:%M:%S')+f' (UTC{s}{o})')"
   ```

## Phase 1: Collect the entry

If the user invoked `/eng-task <freeform description>`, use that as the seed. Otherwise open with: "What's the engineering task? A sentence or two."

Conversational free-form Q&A (like `/report-bug` — no `AskUserQuestion`), one or two questions per turn. Collect:

1. **Background** — why does this work exist? What prompted it (a release, an incident, a design review, groundwork for a future decision)? Push back on "we just should": the motivation is what lets a future reader judge whether the entry is still relevant.

2. **Scope** — which systems, services, or files change. Concrete enough that the planner can judge parallelism and conflict risk.

3. **Acceptance criteria** — bullet list of concrete outcomes. "Pipeline is robust" is not a criterion; "deploy aborts and rolls back automatically when post-deploy smoke checks fail" is.

4. **Verify — mandatory, and it must be mechanically executable.** A command (or short procedure) plus its expected outcome that anyone — coder, tl, or the user — can run to confirm the task is done. Examples:
   - `./scripts/deploy.sh --dry-run` exits 0 and prints the rollback plan
   - `curl -s localhost:8000/api/v2/items | jq .schema_version` returns `"1"` for a v1 client header
   - write a marker row → redeploy → marker row still present

   **Refuse to file an entry without a concrete Verify.** If the user can't state one, the task isn't defined enough to hand to an agent — help them derive one from the acceptance criteria. This is the field that keeps the backlog from becoming a dumping ground of unverifiable work: eng tasks bypass QA's CUJ walks and PM review, so Verify *is* the verification contract (executed by the coder, confirmed by tl at code review).

5. **Priority** — one of:
   - `blocking` — blocks a deploy, a release, or other scheduled work. Outranks all feature work in planning; only MEDIUM+ QA bug fixes rank above it.
   - `P1` — should be scheduled alongside current feature work.
   - `P2` — as capacity allows.

6. **Ordering** (optional) — constraints on when this must land, expressed in terms the pipeline controls: relative to other ENG entries or PRD work ("must merge before any prd-012 implementation"), plus free text for human-executed sequencing ("land before the next backend deploy" — advisory to the human; the loop has no deploy phase). An entry with an Ordering constraint is **never fast-path eligible** (Phase 3).

7. **Relates-to** (optional) — links to a PRD, issue ID, or CUJ this entry supports or was spun off from.

Summarize the entry back and ask "ready to file?" before writing. Don't lock in until the user confirms.

## Phase 2: Write the entry

Append to `docs/eng-backlog.md` (preceded by a `---` separator and a blank line):

```markdown
---

### ENG-NNN: <one-line summary>

- **Filed**: <timestamp from Phase 0>
- **Priority**: blocking | P1 | P2
- **Background**: <why this work exists>
- **Scope**: <systems/files affected, what changes>
- **Acceptance criteria**:
  - <concrete outcome>
  - <concrete outcome>
- **Verify**: <executable check: command(s) + expected outcome>
- **Ordering**: <constraint, or omit the field>
- **Relates-to**: <prd-NNN-slug | Issue <id> | CUJ-<id> | quality/<slug>, or omit the field>
- **Tag**: instrument-blocking (optional — only for entries that gate a quality surface's
  measurement instrument; `/quality-cycle` Q0 refuses to start while any remain open.
  Ordinary hardening stays untagged so the P2 tail never holds the loop hostage.)
```

This block format is the **canonical schema** for ENG entries — tl (which files entries during architecture review) and triage (which spins off discovered debt) copy it.

## Phase 3: Offer the fast path

After filing, assess fast-path eligibility. An entry qualifies only if **both** hold:

- It passes `/quick-fix`'s existing small-scope gate (1–3 files, no design change, no shared interface/data-model change, isolated) — the gate is defined there; don't restate or loosen it here.
- It has **no Ordering constraint**. Ordering is exactly what ad-hoc execution loses; constrained entries go through the planner so grouping can honor them.

If eligible, ask: "This looks small and unconstrained — run `/quick-fix ENG-NNN` now? (y/n)". If yes, invoke it. If no (or not eligible), close with: "Filed as ENG-NNN. The planner will pick it up on the next planning pass (`/dev-cycle` or `/user:planner`)."

## What NOT to do

- **Don't file defects or features here.** Apply the classification rule first; redirect to `/report-bug` or `/design-feature` when it fits those tracks.
- **Don't file an entry without a concrete, executable Verify.** No Verify → no entry.
- **Don't prioritize beyond the three-level field.** Sequencing against CUJs and bugs is the planner's job.
- **Don't implement anything.** Intake only — even for tiny tasks, the fast path goes through `/quick-fix` so its scope guard and cleanup rules apply.
- **Don't renumber or reuse IDs.** Always consume and increment the `Next-ID:` counter.
- **Don't add status fields to entries.** Done entries are removed (the commit referencing the ENG ID is the record); the backlog only holds open work.
