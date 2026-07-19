---
description: Bring an existing project (built without this multi-agent setup) into conformance with the patterns expected by /dev-cycle, /design-feature, and the rest. Audits scattered docs broadly (not just canonical paths), reconciles them per user choice (migrate / adopt / preserve / ignore), scaffolds missing infrastructure (scripts/qa-server.sh, .gitignore), derives design docs from code via the tl agent, backfills PRDs that describe what's actually built via the pm agent (mocks are NOT auto-generated — user runs /design-feature Route D later to add mocks where they want visual fidelity), and seeds docs/status.md. Idempotent — safe to re-run; preserves anything already at canonical paths.
---

# organize-project — Bring an existing project into the multi-agent pattern

You are the orchestrator for organizing an existing project that was created without this multi-agent setup. The project has working code but the documents are missing, partial, or scattered under non-standard names and paths. Your job is to audit what's there, reconcile it, scaffold what's missing, and backfill docs that describe **what's actually built** — not redesign it.

**Idempotent by design.** Safe to re-run. Every phase checks for existing canonical state before writing; only fills gaps, never overwrites.

The flow:

- **Phase 0** — Audit broadly: catalog all markdown files anywhere in the project, classify by content and filename heuristics (PRD-like, design-like, README, status, other).
- **Phase 1** — Confirm product context conversationally: target user, primary problem, value prop, MVP scope.
- **Phase 1.5** — Reconcile existing docs: per-document user decision (migrate / adopt / preserve / ignore).
- **Phase 2** — Bootstrap infrastructure mechanically: `mkdir -p` canonical dirs, create `scripts/qa-server.sh`, update `.gitignore`.
- **Phase 3** — Derive design docs via the `tl` agent: read existing code + adopted/migrated design content, write `docs/design/system.md` + per-component `design-<slug>.md`.
- **Phase 4** — Propose feature → PRD mapping conversationally: group detected features into proposed PRDs, get user confirmation. Skip features already covered by existing canonical PRDs.
- **Phase 5** — Backfill PRDs via the `pm` agent (one invocation per PRD, sequential): read the relevant code + adopted/migrated PRD-like content, generate CUJs that describe what's actually built, write `prd-NNN-<slug>.md`, update `docs/prd/index.md`. **Mocks are not auto-generated** — backfilled CUJs describe existing code, so visual fidelity isn't enforced until you actively want it. The CUJs' "Mocks / Reference Designs" sections state "No mocks (backfilled from existing impl — run /design-feature Route D to add mocks if visual fidelity matters)."
- **Phase 6** — Seed `docs/status.md` via the `status` agent: all CUJs enter with Impl=`merged`, QA=`—`, PM=`—`.
- **Phase 7** — Hand off with summary and suggested next step.

## Phase 0: Audit broadly

Inventory existing state. Don't limit to canonical paths.

### Code + tech-stack identification

- Read `README.md` (if present) — primary source of project intent.
- Read `package.json` (or `Pipfile`, `Cargo.toml`, `go.mod`, etc.) — tech stack, dev command, dependencies.
- Read `package.json`'s `scripts.dev` (or equivalent) and dev-server port — needed for `scripts/qa-server.sh`.
- List top-level source directories (`src/`, `app/`, `routes/`, `pages/`, `components/`, `services/`, `api/`, etc.).
- For web projects, identify routes/screens by reading routing config and major page/component files.
- For backend projects, identify API endpoints.
- For CLI/library projects, identify the public surface (commands, exports).
- Run `git log --oneline -30` for development history and recent focus.

### Markdown audit (the broad part)

Glob `**/*.md` excluding `node_modules`, `.git`, `dist`, `build`, `.next`, `vendor`, `target` (or equivalents). For each file, classify by content **and** filename:

- **PRD-like** — describes user-facing behavior, features, requirements. Filename hints: `SPECS.md`, `REQUIREMENTS.md`, `PRD.md`, `FEATURES.md`, `USER_STORIES.md`, anything under `specs/`, `requirements/`. Content hints: mentions of users, features, "should/must/can," workflows, screen descriptions.
- **Design-like** — architecture, components, data flow. Filename hints: `ARCHITECTURE.md`, `DESIGN.md`, `SYSTEM.md`, anything under `architecture/`, `design/`. Content hints: tech stack, component diagrams, data flow, API contracts.
- **README-like** — project overview, setup, contribution guide. Filename: `README.md`, `CONTRIBUTING.md`, `SETUP.md`, `INSTALL.md`.
- **Status-like** — implementation status, roadmap, changelog. Filename: `STATUS.md`, `ROADMAP.md`, `CHANGELOG.md`.
- **Other** — license, code of conduct, anything else.

Classify by reading the **first 100 lines** of each file — enough to infer content type without burning tokens on long files. If a single file straddles types (a `README.md` that has architecture + features), tag it with multiple types.

Also check for non-standard directories that might hold docs: `docs/`, `documentation/`, `wiki/`, `guides/`, `specs/`, `requirements/`, `design/`, `architecture/`.

### Canonical-path check

For each canonical location, record whether it exists:

- `docs/prd/index.md`
- `docs/prd/prd-NNN-*.md` (list any present)
- `docs/design/system.md`
- `docs/design/design-*.md` (list any present)
- `docs/status.md`
- `scripts/qa-server.sh`
- `.gitignore` (and whether it already excludes `.qa-dev-server.{pid,log}`, `docs/issues-attachments/`, `docs/gorilla/*/screenshots/`)

### Audit summary to the user

Print a structured summary:

> **Project audit**
>
> Product (inferred from README): <one-liner if extractable>
> Tech stack: <list>
> Dev command: `<DEV_CMD>` on port `<DEV_PORT>` (detected from package.json)
>
> Feature surface detected:
> - <route or component A> → looks like the "feature X" area
> - <route or component B> → looks like the "feature Y" area
> - ...
>
> Existing markdown docs (X total, Y classified as PRD-like / design-like / etc.):
> - `README.md` → README-like (project overview, partial architecture)
> - `SPECS.md` → PRD-like (covers features A and B)
> - `docs/old-architecture.md` → design-like (auth layer + data model)
> - ...
>
> Canonical structure already present:
> - `docs/prd/index.md`: missing
> - `scripts/qa-server.sh`: missing
> - `.gitignore` lines: partial (3 of 4 entries present)
> - ...

## Phase 1: Confirm product context (conversational, lightweight)

Drive a short conversational pass to confirm the product context the orchestrator will use to seed `docs/prd/index.md` and inform downstream agents. This is **not** full `/design-feature` Phase 0 — much shorter. The goal is to get a workable vision + persona + scope statement, not to redesign the product.

**No `AskUserQuestion`.** Free-form text, react to answers.

Ask, in roughly this order, one or two at a time:

1. **Product summary** — confirm or correct the inferred one-liner. "Based on the README and code, this looks like [X]. Accurate?"
2. **Target user** — "Who's this for? In a sentence."
3. **Primary problem / value prop** — "What problem does it solve, or what's the one-sentence pitch?"
4. **MVP boundary** — "Of the features I detected (A, B, C, D), which are core vs experimental vs deprecated?"

Wrap when you can describe product / user / value prop / scope in your own words. Capture in working memory — you'll seed `docs/prd/index.md` in Phase 2.

## Phase 1.5: Reconcile existing docs

For each non-canonical doc identified in Phase 0 (PRD-like, design-like, status-like — skip plain READMEs, licenses, changelogs unless they're carrying spec content), present its path + one-line content preview and ask the user to choose:

- **Migrate** — move the content into canonical structure (PRD-like → `docs/prd/prd-NNN-<slug>.md`; design-like → `docs/design/<slug>.md`). Delete the original. Use the existing content as the starting point for the canonical file — the agent in Phase 3 (TL) or Phase 5 (PM) will then refine/extend it.
- **Adopt** — copy to canonical location, leave a one-line stub at the original path pointing to the new location (e.g., `> Moved to docs/design/system.md`). Useful when external tools or links depend on the old path.
- **Preserve** — leave the doc at its current path unchanged. Reference it from the relevant canonical index (e.g., add a "Reference docs" section in `docs/prd/index.md` listing it).
- **Ignore** — leave unchanged, don't reference. The doc continues to exist but isn't part of the canonical surface.

Present the choices as plain text (not `AskUserQuestion`), since you may also want to negotiate per-doc details ("should I split SPECS.md into per-PRD files?").

**Outputs of this phase:**

- A `migrated-content` map: for each canonical destination path, the existing content the agents in Phase 3 / Phase 5 should incorporate.
- A `preserved-refs` list: paths that will be referenced from `docs/prd/index.md` under "Reference docs."
- Any file moves / stubs already performed.

## Phase 2: Bootstrap infrastructure (mechanical, fast)

Skip steps for anything already present. Apply only the missing pieces.

1. **Directory structure:**
   ```bash
   mkdir -p docs/prd docs/design docs/ux scripts
   ```

2. **`docs/prd/index.md`** — write only if missing. Use the Phase 1 confirmed product summary, target user, value prop. Empty PRD listing for now (Phase 5 will populate). Include a "Reference docs" section with the `preserved-refs` from Phase 1.5 if any.

   If the file already exists, leave it alone (Phase 5's PM agent will update its PRD listing as PRDs are backfilled).

3. **`scripts/qa-server.sh`** — write only if missing. Use the canonical template from `claude/agents/qa.md` Step 1a, filling in `DEV_CMD` and `DEV_PORT` from Phase 0 detection. `chmod +x scripts/qa-server.sh` after writing.

4. **`.gitignore`** — append any of these lines that aren't already present:
   ```
   .qa-dev-server.pid
   .qa-dev-server.log
   docs/issues-attachments/
   docs/gorilla/*/screenshots/
   ```
   Don't duplicate existing lines.

5. **Project `CLAUDE.md` pointer** — ensure the project's `CLAUDE.md` contains this two-line pointer (create the file with just these lines if it doesn't exist; append the section if it exists without one):
   ```markdown
   ## Workflow
   This project follows the multi-agent workflow (agents/commands deployed globally
   via the setup repo's `claude/deploy.sh`). Route work through /design-feature,
   /report-bug → /triage, and /eng-task; practices live in the global CLAUDE.md
   ("Workflow Discipline").
   ```
   **Do NOT copy the practice rules themselves into the project** — they live in the global `CLAUDE.md` as the single source. A copied ruleset goes stale the next time the setup evolves, and a stale local copy loaded alongside a fresh global one is exactly the stale-doc-overrides-fresh-spec failure this setup guards against.

After this phase, print a one-line summary of what was created vs preserved.

## Phase 3: Derive design docs via the `tl` agent

Spawn a `tl` subagent to capture the as-is architecture from the existing code (and any adopted/migrated design-like content from Phase 1.5).

Skip this phase if `docs/design/system.md` AND all expected `design-<slug>.md` files already exist (the user has already documented the architecture). If `system.md` exists but specific component docs don't, instruct TL to write only the missing component docs.

Prompt:

```
You are documenting the as-is architecture of an existing project. This
is NOT a redesign exercise — capture what's actually built, faithfully,
so future agents (planner, qa, gorilla, dev-cycle) have a reference.

Existing design-like docs the user wants incorporated (from Phase 1.5):
- <path-A> (covers <topic>)
- <path-B> (covers <topic>)
[If none: "None."]

Read these first if present — they represent the user's existing
documentation of intent, and take precedence over your code-derived
inferences when they conflict. Then read the codebase under the
project's source directories to fill gaps.

Write:
1. docs/design/system.md — cross-cutting: tech stack with rationale,
   high-level architecture diagram (Mermaid), data model overview, API
   conventions, shared patterns, deployment topology. Follow the
   structure in your role definition's "Mandatory elements in system.md"
   section.
2. docs/design/design-<slug>.md per major component identified — follow
   the per-component template in your role definition. Use slugs that
   match the actual code structure (e.g., design-auth.md, design-sync.md,
   design-articles-page.md).

If docs/design/system.md already exists, ENRICH it — don't overwrite.
Fill missing sections; preserve existing content. Same for any existing
design-<slug>.md files.

Be faithful to the code. If something in the code is non-ideal, document
it accurately and note it in "Open Questions & Risks" rather than
silently fixing it in the doc.
```

After TL returns, verify the design docs exist and reflect the code.

## Phase 4: Propose feature → PRD mapping (conversational)

Group the features detected in Phase 0 into proposed PRDs. Skip any feature already covered by an existing canonical `prd-NNN-<slug>.md`.

Present the proposal to the user as plain text:

> Based on the audit, I'd group the features into PRDs as follows:
>
> - **prd-000-articles** — covers the article-listing, article-detail, and tag-filtering screens (CUJs: browse, filter, read).
> - **prd-001-auth** — covers signup, login, password reset (CUJs: register, sign-in, recover-password).
> - **prd-002-sharing** — covers share-via-link and share-to-export (CUJs: copy-link, export-pdf).
>
> The numbering picks up after any existing PRDs in `docs/prd/`. Adjust
> the slugs or groupings, drop any you don't want backfilled, or split
> a group into two PRDs if you'd rather. Confirm the final list before
> I write them.

Iterate with the user until they confirm. Capture the agreed PRD list (slug + feature scope + relevant code paths + relevant adopted/migrated PRD-like content paths).

## Phase 5: Backfill PRDs via the `pm` agent (sequential, one per PRD)

For each agreed PRD, spawn a `pm` subagent. Run them sequentially (not in parallel — each invocation modifies `docs/prd/index.md`, and sequential is simpler).

Prompt (substitute per-PRD content):

```
You are backfilling a PRD for an existing implementation. The code is
already built — your job is to write CUJs that DESCRIBE what's actually
built, faithfully. This is NOT a redesign.

PRD identifier: prd-NNN-<slug>
Feature scope: <list of features / routes / components this PRD covers>

Existing PRD-like docs the user wants incorporated (from Phase 1.5):
- <path> (covers <part of this PRD>)
[If none: "None."]

Read these first if present — they represent the user's intent and take
precedence over your code-derived inferences when they conflict.

Then read the relevant code:
- <list of file/dir paths>

For each user-facing journey you observe in the code:

1. Write a CUJ in your full template format (Context, Preconditions,
   Journey Steps with System Response / User Sees / Details, Edge Cases
   & Error States, Mocks / Reference Designs, Acceptance Criteria as
   plain bullets).

2. The Journey Steps should describe what happens in the running product
   today. If you observe something in the code that's broken or
   half-implemented, note it under Edge Cases or in the CUJ's "Open
   questions" line rather than silently fixing it in the spec.

3. Each acceptance criterion must be observable in the running product.

4. In the "Mocks / Reference Designs" section, state:
   "No mocks (backfilled from existing impl — run /design-feature
   Route D to add mocks if visual fidelity matters)."
   Do NOT generate mocks here. They're a separate, user-driven step
   if/when the user wants visual fidelity testing for this feature.

Then:
- Write docs/prd/prd-NNN-<slug>.md
- Update docs/prd/index.md with a new entry. If the index doesn't yet
  list the PRD, add it under the "PRD listing" section.

Return: a one-line summary plus the list of CUJ-IDs created.
```

After each PM run, briefly note progress to the user ("prd-000-articles done, 4 CUJs; moving on to prd-001-auth").

## Phase 6: Seed `docs/status.md` via the `status` agent

Spawn the `status` agent with route awareness — this is similar to `/design-feature` Phase 2.5 but covers all the newly backfilled PRDs at once.

Prompt:

```
Refresh docs/status.md. The /organize-project skill just backfilled
PRDs for an existing implementation. Every CUJ in the new PRDs starts
with:
  - Impl: merged (the code exists)
  - QA: — (no QA run yet)
  - PM: — (no PM review yet)

If docs/status.md already exists, preserve every existing row and append
rows for the new CUJs.

Follow your Section 4 template exactly.
```

## Phase 7: Hand off to the user

Print a single concise summary tailored to what was created and what was preserved:

```
Project organized.

Created:
- docs/prd/index.md (vision, persona, PRD listing with N PRDs)
- docs/prd/prd-NNN-<slug>.md × N (no mocks — backfilled from impl)
- docs/design/system.md
- docs/design/design-<slug>.md × N
- docs/status.md (X CUJs at Impl=merged, QA=—, PM=—)
- scripts/qa-server.sh (chmod +x; DEV_CMD=<X>, DEV_PORT=<Y>)

Preserved unchanged:
- <list of canonical files that already existed and were left alone>

Migrated / adopted:
- <list of doc moves performed in Phase 1.5>

Suggested next step: run `/dev-cycle` to walk every CUJ through QA + PM
review. Expect findings — the impl predates the spec, so QA may surface
gaps between code and the backfilled CUJs. Address them with /quick-fix
or refine the PRDs via /design-feature Route D as needed.

If you want visual fidelity testing for any CUJ, run `/design-feature`
and pick Route D — the conversational PM agent will walk through the
existing CUJ, draw mocks for the agreed states, and save them under
`docs/ux/<prd-dir>/`. Backfilled CUJs ship without mocks by default.
```

If the project was already mostly organized and the skill did little ("idempotent re-run"), say so honestly:

```
Project already mostly organized. The skill verified canonical structure
and filled <N> small gaps:
- <list of small additions>

Nothing else needed change.
```

## What NOT to do

- **Don't overwrite anything at a canonical path.** Every phase checks for existence and either skips or enriches gaps. The user may have hand-written PRDs you'd destroy if you blind-write.
- **Don't redesign the project.** Phase 3 TL and Phase 5 PM are documenting **what's built**, not what should be built. If code is non-ideal, document it accurately and flag it under "Open questions" — refinement is a follow-up task via `/design-feature` Route D, not this skill.
- **Don't drop content from migrated docs.** When migrating `SPECS.md` into `docs/prd/prd-NNN-<slug>.md`, the migrated content is the **starting point** for PM's CUJ-writing. PM should incorporate it, not ignore it in favor of code-derived inference.
- **Don't run Phase 5 in parallel.** Each PM invocation updates `docs/prd/index.md`. Sequential avoids merge conflicts; the time cost is small for typical projects (1-5 PRDs).
- **Don't skip Phase 1.5 by guessing.** When non-canonical docs exist, present them to the user and get their decision. Migrating without permission destroys their existing structure; ignoring without notice leaves orphaned content.
- **Don't auto-trigger `/dev-cycle` after handoff.** The user should review the backfilled docs before running QA against them. Suggest as the next step; don't invoke.
- **Don't fabricate CUJs that aren't in the code.** Phase 5's PM is bound to what's observable in the running product. If a feature is half-built, document it half-built (CUJ with partial Journey Steps + "Open question" noting the gap), not as a fully-specified intent.
- **Don't claim the project is "ready for production" after organizing.** Onboarding just produces docs that match the existing impl. Quality issues, missing tests, and unimplemented edges all remain — surfaced by `/dev-cycle`'s QA in a subsequent run.
