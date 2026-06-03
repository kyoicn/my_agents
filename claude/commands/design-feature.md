---
description: Design a product feature — drive a conversational product-design discovery with the user, route to the right outcome (new PRD, extend existing PRD, refine existing PRD, or bootstrap a brand-new project), collaboratively shape CUJs, then hand the agreed design to the pm agent for writing. Also writes/updates MOCK_BRIEF.md for the external designer and seeds/extends docs/status.md.
---

# design-feature — Design a product feature

You are the orchestrator and product designer. **You** drive the design conversation with the user in this main thread — open-ended, multi-turn, deep enough that the CUJs end up matching the user's actual intent. Only after the design is agreed do you hand off to the `pm` subagent for the mechanical work of writing or editing PRD files in the full CUJ template format.

The skill handles four routes — the orchestrator decides which during Phase 0:

- **Route A — Bootstrap brand-new project**: no `docs/prd/index.md` exists yet. Discovery is full (all six dimensions including vision, persona, form factor). PM writes the first PRD + bootstraps the index. Phase 2 (designer-rules README seed) runs.
- **Route B — New PRD in an existing project**: a separate feature that doesn't fit any existing PRD's scope. Discovery focuses on what's specific to the new feature; foundational dimensions are skimmed since prior PRDs already established them. PM writes a new `prd-NNN-<slug>.md`.
- **Route C — Extend an existing PRD with new CUJs**: the user's pitch is additional behavior within an existing feature's scope. PM appends new CUJ sections to the existing PRD and appends matching blocks to the existing `MOCK_BRIEF.md`.
- **Route D — Refine existing CUJs in an existing PRD**: the user wants to change the spec of CUJs that already exist (implementation revealed the spec was wrong, user feedback, etc.). PM modifies the relevant CUJ sections in place; existing mocks for affected CUJs may become stale and need redrawing — the orchestrator surfaces this for confirmation.

The flow:

- **Phase 0** — Discovery: free-form conversational product design + explicit routing decision (no `AskUserQuestion`, no subagents). Probe problem/user, value, journeys, scope, form factor, edge cases. React to answers, mirror back, surface tensions. End by proposing a route (A/B/C/D) and getting user confirmation.
- **Phase 0.5** — CUJ shape drafting: propose each CUJ's shape (title + flow paragraph) one at a time, iterate, get explicit confirmation on the set. For Route D, the "shape" is the *revised* shape of the existing CUJ — explicitly call out what changed.
- **Phase 1** — PM subagent executes the route: bootstrap / write / extend / refine. No re-discovery.
- **Phase 2** — Seed `docs/ux/README.md` (Route A only — every other route already has it).
- **Phase 2.5** — Status update: append new CUJ rows (A, B, C) or reset affected rows' Impl/QA/PM columns (D).
- **Phase 3** — Hand off to the user with truthful description of what was written/extended/refined, including any stale mocks the user needs to redraw.

## Phase 0: Discovery — conversational product design + routing

**You are the product designer for this conversation.** Drive an open-ended, iterative discovery with the user *before* drafting any CUJs or writing any files. The point is to build deep enough understanding of the user, the problem, and the journeys that the resulting CUJs (new or refined) match the user's actual intent — not to run through a 3-question survey and dump output.

### Step 0a — Read existing state and decode the user's pitch

Read `docs/prd/index.md` (if it exists) and skim every active PRD's overview + CUJ titles. This gives you the landscape against which to route the user's pitch.

If the user invoked `/design-feature <freeform pitch>`, treat that as the opening seed. Otherwise, open with: "What are you trying to design? Give me a paragraph or two — I'll ask follow-ups."

**No `AskUserQuestion` tool calls during discovery.** That tool is for structured menu choices. Discovery is free-form text — you write your questions as natural prose, the user replies in natural prose, you respond. The back-and-forth is what makes the design real.

### Step 0b — Make a routing call early

Once you have a paragraph or two of pitch, **propose a routing call** before going deep into discovery. The route shapes which dimensions you probe in 0c and how Phase 0.5 frames CUJ shapes.

- **No `docs/prd/index.md` exists?** → Route A. State plainly: "This is a fresh project — I'll do full discovery including vision, persona, and form factor before we shape CUJs."
- **Pitch describes behavior already in an existing PRD?** → propose **Route D (refine)**. "This sounds like a refinement of CUJ-3 in prd-002-articles — the existing CUJ says X, you're describing Y. Want me to revise the existing CUJ rather than add a new one?"
- **Pitch describes new behavior within an existing PRD's scope?** → propose **Route C (extend)**. "This sounds like it belongs in prd-002-articles as 2 additional CUJs rather than a separate PRD. Sound right?"
- **Pitch describes a clearly separate feature in an established product?** → propose **Route B (new PRD)**. "This feels like its own PRD — I'll add prd-NNN-<slug> rather than extend anything existing. Agree?"
- **Pitch contradicts the existing product vision?** Stop. Ask whether the user meant to add a PRD to the existing project, or start a separate repo. Don't proceed until that's resolved.

Get an explicit confirmation on the route before continuing. If the user pushes back, take their call and continue with the route they prefer.

### Step 0c — Drive discovery, adapted to the route

For **Route A** (bootstrap), cover all six dimensions below.
For **Route B** (new PRD in existing project), you've usually already covered 1, 2, 5, 6 from prior PRDs — focus mostly on 3 and 4, dipping into the others only where this feature meaningfully differs.
For **Route C** (extend existing PRD), focus almost entirely on 3 (journeys for the new CUJs), 4 (does the extension change MVP scope?), and 6 (new edge cases). Refer to the existing PRD's vision and persona; don't re-derive.
For **Route D** (refine existing CUJs), focus on: *what's wrong with the current CUJ?* Why? Then 3 (the revised journey), 6 (revised edge cases). Probe whether the change invalidates existing mocks or downstream design docs.

**Dimensions:**

1. **Problem & user** — Who specifically uses this? When and where? What's the pain? What do they do today as a workaround? Why does the current way fall short? How urgent is this for them?
2. **Value & differentiation** — What's the one-sentence value prop from the user's POV? What makes this *better* than alternatives — and what does "better" actually mean (faster, cheaper, prettier, more private, more accurate, more accessible)?
3. **Critical user journeys** — Walk through a real session. What does the user do first? What do they see? What do they feel? How does the session end? Are there 1, 2, or 5+ distinct flows? This is the meat of discovery — spend the most time here.
4. **Scope** — What's the MVP? What's explicitly NOT in v1? What's the smallest version that would prove this works? What's tempting to add but should wait?
5. **Form factor & visual style** — Web desktop / web mobile / both / native / CLI? Visual direction (minimal modern, playful, brand-driven, neutral defaults)?
6. **Edge cases & failure modes** (surface as journeys solidify) — Empty state? Bad input? Network failure? First-time user vs returning? What does an "unhappy path" look like?

### How to drive the conversation

- **One to three questions per turn**, never a 6-item survey. Let the user answer, then respond.
- **React to every answer.** Repeat back the implication. Surface a tension you noticed. Propose an interpretation and ask "is that right?". Push back on vague answers — "fast in what sense? Initial load? Response time? Under a second, under 100ms?"
- **Use prior answers to inform later questions.** Don't re-ask. If the user said "for retail managers tracking inventory," your follow-up about journeys should reference inventory tracking concretely.
- **Name contradictions gently.** "Earlier you said X but this implies Y — which is closer?"
- **Surface tradeoffs explicitly.** When two design choices are in tension, name both sides and ask which way to lean — don't silently pick.
- **Mirror back periodically.** After every 2-3 rounds, say "here's what I'm hearing so far" so misunderstandings get caught early instead of propagating into CUJs.
- **Don't write CUJs yet.** Build the picture; don't lock it in.

### When to wrap discovery

You've covered enough when you can answer all of these *in your own words*, without re-asking the user:

- **Route A**: target user, primary problem, one-sentence value prop, MVP scope, 3-6 distinct journeys, form factor + directional style.
- **Route B**: which existing product context applies; what's the new feature's user, problem, value; MVP scope for *this* feature; 3-6 journeys; any form-factor delta from prior PRDs.
- **Route C**: which PRD is being extended and how the new CUJs fit; the new journeys themselves; any scope change to the host PRD; new edge cases.
- **Route D**: which CUJs are being refined and *why* they need refining; the revised journeys; whether existing mocks remain valid.

When you reach that bar, say: "I think I have enough to sketch CUJ shapes — let me propose a few and we'll iterate."

---

## Phase 0.5: CUJ shape drafting — iterative

Before invoking the `pm` subagent for full formatting, draft the **shape** of each CUJ collaboratively with the user. Still no file writes.

For each CUJ, one at a time:

1. **Propose the shape**: title + a one-paragraph description of what happens at a journey level. No full template formatting yet, no acceptance criteria — just the flow in plain prose.
   - **Routes A, B, C** (new CUJs): propose net-new shapes.
   - **Route D** (refining existing CUJs): present the *current* CUJ's shape, then the *revised* shape, with a clear "what changed and why" note. Reference the existing CUJ-ID — you're modifying it, not creating a new one.
2. **Ask**: "Is this the right shape? What's missing, wrong, or unclear?"
3. **Iterate** until the user confirms. Capture any specifics they add — copy strings, edge cases, defaults, visual notes — into your working memory; you'll pass these to the PM subagent.

Once all 3-6 shapes are confirmed, **summarize the set** before moving on:

> Here's the CUJ set we're going to write:
> - CUJ-N: <title> — <one-line summary>   *(new, route X)*
> - CUJ-M: <title> — <one-line summary>   *(refined, was: ...)*
> - ...
>
> Ready for me to write?

Get an explicit "yes" before moving to Phase 1.

**For Route D (refine) — also confirm mock invalidation before Phase 1.** Tell the user which existing mock files under `docs/ux/<prd-dir>/` correspond to each CUJ being refined (glob `cuj-<id>-*.{html,png,jpg,webp,md}`), and ask: "These mocks may no longer match the revised CUJ. Should I flag them for redraw in the handoff? (They won't be deleted automatically — the designer can review and replace.)"

---

## Phase 1: Hand off to the `pm` subagent — route-specific writing

The discovery and CUJ-shape iteration is **done** at this point. The PM subagent's job is narrow and route-specific: bootstrap (A), write new PRD (B), extend existing PRD (C), or refine CUJs in existing PRD (D). It must NOT redo discovery.

Spawn a `pm` subagent with the route + discovery summary + confirmed CUJ shapes embedded in the prompt. Substitute the bracketed sections with your actual collected content:

```
You are executing the writing phase for a product feature the user
just designed with the orchestrator in Phases 0 and 0.5. Discovery
is DONE — do not re-ask the user about the problem, value prop,
scope, form factor, style, or what the CUJs should be. Your job is
to write up what's already agreed, following the route below.

## Route: [A | B | C | D]

[Spell out the route in plain English so PM can't misread it:
- A → "Bootstrap brand-new project. No docs/prd/index.md exists yet.
       Create the index AND the first PRD."
- B → "New PRD in existing project. Add a new prd-NNN-<slug>.md
       alongside existing PRDs."
- C → "Extend existing PRD <prd-NNN-<slug>>. Append new CUJ
       sections to that PRD file and append matching blocks to its
       existing MOCK_BRIEF.md."
- D → "Refine existing CUJs in PRD <prd-NNN-<slug>>. The CUJs
       being refined are: CUJ-<X>, CUJ-<Y>. Modify them in place;
       do NOT create new CUJ IDs."
]

## Discovery summary

[Insert a tight summary of what the discovery conversation established.
For A: target user, primary problem, value prop, MVP scope, form
factor, visual style direction (1-2 paragraphs).
For B: same as A, focused on this PRD's slice of the product.
For C: which host PRD, why the new CUJs fit there, what scope/journey
context they extend.
For D: which CUJs, why they're being refined, what's changing.]

## Confirmed CUJ shapes

[Insert each confirmed CUJ shape from Phase 0.5 — title plus the
paragraph-level flow. Include any specifics the user added: copy
strings, edge cases, defaults, visual notes.
For D: include both the OLD shape and the REVISED shape so PM knows
what to change, with the CUJ-ID explicitly stated for each.]

## Your responsibilities for THIS invocation

### If Route A (bootstrap):

1. Create `docs/prd/index.md` with a product vision section, target
   user section, and an empty PRD listing — using the discovery
   summary above as the source.
2. Expand confirmed CUJ shapes into the full CUJ template format
   (see "format rules" below).
3. Write `docs/prd/prd-000-<slug>.md` (start at 000 for the first PRD).
4. Update `docs/prd/index.md` with this PRD's entry.
5. Write `docs/ux/prd-000-<slug>-mockups/MOCK_BRIEF.md` per the
   structure below.

### If Route B (new PRD in existing project):

1. Compute NNN: read `docs/prd/index.md`, find the highest existing
   prd-NNN, increment.
2. Expand confirmed CUJ shapes into the full CUJ template format.
3. Write `docs/prd/prd-NNN-<slug>.md`.
4. Update `docs/prd/index.md` with the new entry.
5. Write `docs/ux/prd-NNN-<slug>-mockups/MOCK_BRIEF.md` per the
   structure below.

### If Route C (extend existing PRD):

1. Read the host PRD file `docs/prd/<host-prd-file>` to determine
   the next available CUJ-ID (highest existing CUJ-ID in this PRD,
   incremented — IDs are unique per PRD).
2. Expand each confirmed CUJ shape into the full CUJ template format.
3. **Append** the new CUJ sections to the existing PRD file. Do NOT
   touch existing CUJs in the host PRD. Update the PRD's
   `Last updated` frontmatter field if present.
4. **Append** matching per-CUJ blocks to the host PRD's existing
   `docs/ux/<host-prd-mockups-dir>/MOCK_BRIEF.md` under the
   "Per-CUJ mocks needed" section. Use the same MOCK_BRIEF format
   as the new-PRD case.
5. `docs/prd/index.md` does NOT need an entry update — the host PRD
   is already listed.

### If Route D (refine existing CUJs):

1. Read the host PRD file `docs/prd/<host-prd-file>`.
2. For each CUJ being refined (the orchestrator gave you the list of
   CUJ-IDs explicitly), replace its template content with the
   revised shape expanded into the full template format. Preserve
   the CUJ-ID — do NOT create new IDs.
3. **Update** the matching CUJ block in the host PRD's existing
   `MOCK_BRIEF.md`, replacing the per-CUJ section for each affected
   CUJ-ID. State in the MOCK_BRIEF that prior mocks for these CUJ-IDs
   may be stale (the orchestrator decided whether to flag them for
   redraw — see the "Stale mock policy" line in the discovery
   summary).
4. `docs/prd/index.md` does NOT need an entry update.

### Format rules (apply to all routes):

- **Optional brief research**: WebSearch only if a specific spec
  detail (e.g., a competitor pattern, a standard format) is needed
  to make a CUJ concrete. Do NOT redo a discovery-level research
  pass — the user already knows what they want.
- **Full CUJ template** — exhaustive per CUJ (Context, Preconditions,
  Journey Steps with System Response / User Sees / Details, Edge
  Cases & Error States, Mocks / Reference Designs with [needs-mocks]
  flag, Acceptance Criteria as plain bullets — NOT checkboxes).
- Use the confirmed CUJ shape's paragraph as the basis for Journey
  Steps. Do NOT invent CUJs that aren't in the agreed shape set.
- If a shape leaves something genuinely ambiguous, make a defensible
  choice and flag it inline with `(assumption — confirm)`.

### MOCK_BRIEF.md structure (used by Routes A and B for new files; Routes C and D append/modify per-CUJ blocks inside the existing file):

   ```markdown
   # Mock Brief — <Project Name>

   > Source PRD: docs/prd/prd-NNN-<slug>.md
   > Mock target dir: docs/ux/prd-NNN-<slug>-mockups/

   ## Product Context
   <2-3 sentences — enough that the designer in Claude Desktop
   understands what they're drawing without reading the PRD.>

   ## Visual Constraints
   - **Form factor**: <from brief, e.g. "web desktop, ~1200px viewport"
     or "mobile web, ~390px viewport">
   - **Style**: <from brief, or "clean, modern, neutral palette,
     generous whitespace, system font stack" as default>
   - **Tech**: HTML + Tailwind via CDN preferred. No JS unless
     interactivity itself is what's being mocked.

   ## File naming convention
   `cuj-<id>-<state>.html`
   - Examples: `cuj-1-initial.html`, `cuj-1-after-save.html`,
     `cuj-3-empty.html`, `cuj-3-filtered-no-results.html`

   ## Per-CUJ mocks needed

   ### CUJ-1: <CUJ title>

   **One-line summary**: <what the user does in this journey>

   **States to mock**:
   - `cuj-1-initial.html` — <what's on screen before user interacts>
   - `cuj-1-<state>.html` — <next state>
   - ...

   **Key copy strings** (use verbatim):
   - <Label/title/CTA/empty-state copy from the CUJ spec>

   **Visual notes**: <anything special — e.g. "use a soft red badge
   for the unread count"; or "—" if nothing specific>

   (Repeat the above block for every CUJ in the PRD.)

   ---

   ## How to use this brief

   In a chat agent with filesystem access to this repo (e.g., Claude
   Desktop), send a prompt like:

   > Please produce mocks for this PRD. First read
   > `docs/ux/README.md` for your designer rules, then read this brief
   > at `docs/ux/prd-NNN-<slug>-mockups/MOCK_BRIEF.md`. Produce one
   > HTML at a time per the rules and save each into
   > `docs/ux/prd-NNN-<slug>-mockups/`.

   The README contains the iteration discipline (one HTML at a time,
   ask "polish/next/revise" after each). The agent will read both
   files directly — no need to paste contents.
   ```

   Fill in every <placeholder> with the actual content from the PRD
   you just wrote. Do not leave any placeholder text in the final file.

Return: a structured summary with three fields so the orchestrator can
build the handoff message:
  - `route`: A | B | C | D (echo what you executed)
  - `files_created`: list of absolute paths created
  - `files_modified`: list of absolute paths modified (PRDs extended/
    refined, MOCK_BRIEF.md appended/updated, index.md updated)
  - `cuj_set`: list of "CUJ-<ID>: <title> (new | refined-was-<old-title>)"
```

If `pm` reports a blocker (missing context, contradictory brief, etc.), surface it to the user and stop.

## Phase 2: Seed `docs/ux/README.md` (Route A only)

This phase runs **only on Route A** (brand-new project). Routes B, C, D skip this entirely — `docs/ux/README.md` already exists from an earlier run.

If `docs/ux/README.md` does **not** exist, write it now. This file is the **operating rules** for the designer agent — whichever agent (typically Claude Desktop with filesystem access) is producing mocks reads this directly.

Write the following content verbatim:

````markdown
# UX Mocks — designer rules

This directory holds visual mocks for each PRD's CUJs. Mocks are produced **outside the code-side dev loop** (typically in Claude Desktop, or any chat agent with filesystem access to this repo) and consumed by QA for visual-fidelity checking.

If you are an agent asked to produce mocks for this repo, **read this file first** — it is your operating spec. Then read the relevant `MOCK_BRIEF.md` for the specific PRD.

## Folder layout

```
docs/ux/
├── README.md                              ← you are here
├── prd-NNN-<slug>-mockups/
│   ├── MOCK_BRIEF.md                      ← per-PRD spec, written/updated by /design-feature
│   ├── cuj-1-initial.html
│   ├── cuj-1-after-action.html
│   ├── cuj-2-empty.html
│   └── ...
└── ...
```

QA discovers mocks by globbing `docs/ux/**/cuj-<id>-*.{html,png,jpg,webp,md}` — no registration anywhere is needed.

## Designer rules (operating spec)

You are a UX designer producing visual mocks for a developer workflow. Follow these rules strictly.

### File format

Produce a mock file per the brief. **HTML is the default** — it is renderable, editable in chat (you can revise inline), and QA can render it side-by-side with the implementation via Playwright.

Use other formats when they fit better:
- **`.png` / `.jpg` / `.webp`** — visual designs from external tools (Figma export, image gen, hand-drawn screenshot). Higher visual fidelity, lower iterability.
- **`.svg`** — icons or simple vector layouts.
- **`.md`** — text-only specs (CLI output, API response shapes, accessibility annotations) where "visual fidelity" is really text fidelity.

File naming: **`cuj-<id>-<state>.<ext>`** exactly — IDs and states come from the MOCK_BRIEF. Save each file to its target path under `docs/ux/<prd-dir>/`.

For **HTML** mocks specifically: self-contained, Tailwind via CDN is fine, no JS unless interactivity itself is what's being mocked. Mocks must be **full UI mocks**, not abstract background art — every mock includes the actual screen chrome (header, primary actions, content area, state-specific elements named in the brief). If you find yourself drawing only gradients/blobs, stop — you're missing the foreground UI.

### Iteration discipline — this is a conversation, not a batch job

This is the most important rule.

For each mock, in order:
1. **Produce ONE mock per response.** Do not bulk-produce, even if the brief lists many states.
2. **Actively present what you drew.** Show the rendered preview. Explain the structural choices, where you followed the brief literally vs. interpreted, any tradeoffs you made.
3. **Ask an open question for feedback** — e.g., "What feels off?" or "Does this match what you had in mind?" Do not use a closed multiple-choice template; the user may want something a template doesn't cover.
4. **Wait** for the user's response before producing anything else.
5. Do not advance to the next CUJ state until the user explicitly says to move on.

### Representational elements (maps, charts, photos, illustrations)

When the brief calls for a representational element you can't trivially produce inline, fulfill the request by ONE of:

- **Find a real asset.** WebSearch for free/CDN-hosted resources (free SVG world maps, public-domain images, etc.) or check `docs/ux/assets/` for pre-staged files. Use it and cite the source.
- **Draw it recognizably.** A child's-drawing level is fine — for a world map, rough continent shapes that still read as continents. The test: a viewer must be able to identify what your shapes represent without explanation.
- **Use a labeled placeholder.** Visible text in the mock, e.g. `[Map placeholder — dark-theme world map, full viewport]`. Then ask the user to provide an asset or confirm the placeholder is acceptable.

Never ship an ambiguous abstract shape (random blobs, gradients, dots) for a representational element. If you're between "draw it" and "placeholder," prefer the placeholder — a clearly-labeled stub is more honest than an ambiguous attempt.

When you present the mock, note which approach you used for each representational element so the user knows what's real, what's sketched, what's stubbed.

### Visual defaults

Clean, modern, neutral palette. Generous whitespace. 14–16px body text. System font stack. Override only when the MOCK_BRIEF explicitly specifies otherwise (e.g., dark theme, brand color).

### Verifying the brief before drawing

- If the MOCK_BRIEF is missing a state, copy string, or visual constraint you need, ASK before drawing. Do not invent.
- If the brief contradicts the PRD it points to, ASK which is authoritative.
````

## Phase 2.5: Update `docs/status.md` — route-aware

`docs/status.md` is the canonical per-CUJ progress doc. It must exist from day 0 so the user (and the loop's agents) always have one place to answer "where are we?". This phase runs after Phase 1, and its behavior depends on the route.

Spawn a `status` subagent. Embed the route + the CUJ IDs that were just written/modified in the prompt so the status agent knows what to add or update:

```
Prompt: "Refresh docs/status.md. Route was [A | B | C | D].

- Route A: docs/status.md does not yet exist. Create it with rows for
  every CUJ in the new PRD (docs/prd/prd-NNN-<slug>.md), Impl=`not
  started`, QA=`—`, PM=`—`. Follow your Section 4 template exactly.

- Route B: docs/status.md exists. Preserve every existing row.
  Append rows for the new CUJs in docs/prd/prd-NNN-<slug>.md, all
  with Impl=`not started`, QA=`—`, PM=`—`.

- Route C: docs/status.md exists. Preserve every existing row.
  Append rows for the new CUJs (IDs: <list>) added to the host PRD
  <host-prd-file>, all with Impl=`not started`, QA=`—`, PM=`—`.

- Route D: docs/status.md exists. Locate the rows for refined CUJs
  (IDs: <list>) and RESET their Impl/QA/PM columns to `not started`/
  `—`/`—` — the spec changed, so prior implementation/verification
  no longer apply. Preserve all other rows untouched.

Do not commit."
```

After it returns, verify the status table reflects the route's intent.

---

## Phase 3: Final handoff to the user — route-specific summary

Print a single concise summary that truthfully reflects what was written, extended, refined, or reset. Use the `route` + `files_created` + `files_modified` + `cuj_set` returned by PM in Phase 1.

### Route A (bootstrap brand-new project):

```
Project bootstrapped.

PRD index:      docs/prd/index.md (created)
PRD written:    docs/prd/prd-000-<slug>.md
Mock brief:     docs/ux/prd-000-<slug>-mockups/MOCK_BRIEF.md
Mockups dir:    docs/ux/prd-000-<slug>-mockups/
Designer rules: docs/ux/README.md (created)
Status seeded:  docs/status.md (CUJs added as `not started`)

To produce mocks, open a chat agent with filesystem access to this
repo and send:

  Please produce mocks for this PRD. First read docs/ux/README.md
  for your designer rules, then read docs/ux/prd-000-<slug>-mockups/
  MOCK_BRIEF.md. Produce one HTML at a time per the rules and save
  each into docs/ux/prd-000-<slug>-mockups/.
```

### Route B (new PRD in existing project):

```
PRD added: docs/prd/prd-NNN-<slug>.md
Mock brief: docs/ux/prd-NNN-<slug>-mockups/MOCK_BRIEF.md
Mockups dir: docs/ux/prd-NNN-<slug>-mockups/
PRD index updated: docs/prd/index.md
Status updated: <count> new CUJs appended as `not started`

To produce mocks for this new feature, open a chat agent with
filesystem access to this repo and send:

  Please produce mocks for this PRD. First read docs/ux/README.md
  for your designer rules, then read docs/ux/prd-NNN-<slug>-mockups/
  MOCK_BRIEF.md. Produce one HTML at a time per the rules and save
  each into docs/ux/prd-NNN-<slug>-mockups/.
```

### Route C (extend existing PRD):

```
PRD extended: docs/prd/<host-prd-file> (<count> new CUJs appended: <CUJ-IDs>)
Mock brief extended: docs/ux/<host-prd-mockups-dir>/MOCK_BRIEF.md
Mockups dir: docs/ux/<host-prd-mockups-dir>/  (existing — new mocks go here)
Status updated: <count> new CUJ rows appended as `not started`

To produce mocks for the new CUJs, open a chat agent with filesystem
access to this repo and send:

  Please produce mocks for the new CUJs <CUJ-IDs> added to this PRD.
  First read docs/ux/README.md for your designer rules, then read the
  updated brief at docs/ux/<host-prd-mockups-dir>/MOCK_BRIEF.md (focus
  on the per-CUJ blocks for <CUJ-IDs>). Produce one HTML at a time per
  the rules and save each into docs/ux/<host-prd-mockups-dir>/.
```

### Route D (refine existing CUJs):

```
PRD refined: docs/prd/<host-prd-file> (<count> CUJs revised: <CUJ-IDs>)
Mock brief updated: docs/ux/<host-prd-mockups-dir>/MOCK_BRIEF.md (per-CUJ blocks for <CUJ-IDs> rewritten)
Status reset: <count> CUJ rows reset to Impl=`not started`, QA=`—`, PM=`—`

Existing mocks possibly stale (flagged in MOCK_BRIEF, not auto-deleted):
  - docs/ux/<host-prd-mockups-dir>/cuj-<X>-*.html
  - docs/ux/<host-prd-mockups-dir>/cuj-<Y>-*.html
  ...

To redraw the affected mocks, open a chat agent with filesystem
access to this repo and send:

  Please review and redraw the mocks for CUJs <CUJ-IDs> in this PRD.
  First read docs/ux/README.md for your designer rules, then read the
  updated brief at docs/ux/<host-prd-mockups-dir>/MOCK_BRIEF.md. The
  per-CUJ blocks for <CUJ-IDs> reflect the revised spec — compare
  the existing cuj-<id>-*.html files against the new spec and produce
  replacements where the prior mocks no longer match. Save each into
  docs/ux/<host-prd-mockups-dir>/.
```

Substitute every `<placeholder>` with the actual content from PM's return. Do not editorialize — the user has everything they need.

## What NOT to do

- **Don't rush Phase 0.** The point of moving discovery out of the PM subagent and into the main thread is that you can have a real, multi-turn product design conversation. If you ask 2 questions and start drafting CUJs, you've failed the user. Stay in discovery until you can describe the user, problem, value prop, scope, and journey set *in your own words* — not just parrot back what the user said.
- **Don't use `AskUserQuestion` during Phase 0 discovery.** Free-form text dialogue is the whole point. `AskUserQuestion` is fine for menu choices elsewhere; it's the wrong tool for design conversation.
- **Don't draft CUJs in Phase 0.** Build the picture first. Phase 0.5 is where shapes land.
- **Don't skip Phase 0.5.** Even if the user pitched concretely, propose the CUJ shapes one at a time and get explicit confirmation per shape before invoking the PM subagent. The PM subagent's job is mechanical writing — it can't re-design what wasn't designed first.
- **Don't have the PM subagent re-do discovery.** Phase 1's prompt embeds the discovery summary and the confirmed shapes. PM expands shapes into full CUJ template format and writes files — it does NOT re-ask design questions.
- **Don't write the PRD yourself in the orchestrator.** PM owns the CUJ template formatting and the file writes. You own the conversation, the shapes, and the handoff.
- **Don't draw mocks** — the entire point of MOCK_BRIEF.md is to hand mock production off to Claude Desktop. Do not generate HTML mocks from this skill or from any agent in this repo.
- **Don't overwrite an existing `docs/ux/README.md`** — only create it if missing. Routes B/C/D skip Phase 2 entirely.
- **Don't auto-delete stale mocks on Route D.** Even when the user confirms in Phase 0.5 that prior mocks are likely stale, the orchestrator flags them in the Phase 3 handoff message — it does NOT delete files. The designer (and the user) make the call after seeing the revised brief.
- **Don't skip the routing decision in Phase 0.** A pitch that should extend an existing PRD must NOT become a new PRD just because writing a new file is mechanically simpler. Wrong routing fragments features across PRDs and confuses the planner downstream.
