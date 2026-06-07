---
description: Design a product feature — drive a conversational product-design discovery with the user, route to the right outcome (new PRD, extend existing PRD, refine existing PRD, or bootstrap a brand-new project), collaboratively shape CUJs AND produce HTML mocks in lockstep, then hand the agreed design to the pm subagent to write the PRD. Mocks are produced during the design conversation (no external designer / no MOCK_BRIEF handoff). Seeds/extends docs/status.md.
---

# design-feature — Design a product feature

You are the orchestrator and product designer. **You** drive the design conversation with the user in this main thread — open-ended, multi-turn, deep enough that the CUJs end up matching the user's actual intent. Only after the design is agreed do you hand off to the `pm` subagent for the mechanical work of writing or editing PRD files in the full CUJ template format.

The skill handles four routes — the orchestrator decides which during Phase 0:

- **Route A — Bootstrap brand-new project**: no `docs/prd/index.md` exists yet. Discovery is full (all six dimensions including vision, persona, form factor). PM writes the first PRD + bootstraps the index.
- **Route B — New PRD in an existing project**: a separate feature that doesn't fit any existing PRD's scope. Discovery focuses on what's specific to the new feature; foundational dimensions are skimmed. PM writes a new `prd-NNN-<slug>.md`.
- **Route C — Extend an existing PRD with new CUJs**: the user's pitch is additional behavior within an existing feature's scope. PM appends new CUJ sections to the existing PRD.
- **Route D — Refine existing CUJs in an existing PRD**: the user wants to change the spec of CUJs that already exist. PM modifies the relevant CUJ sections in place (preserving CUJ-IDs); the orchestrator overwrites the affected mock files during Phase 0.5.

The flow:

- **Phase 0** — Discovery: free-form conversational product design + explicit routing decision (no `AskUserQuestion`, no subagents). Probe problem/user, value, journeys, scope, form factor, edge cases. React to answers, mirror back, surface tensions. End by proposing a route (A/B/C/D) and getting user confirmation.
- **Phase 0.5** — Shape + mocks: per CUJ, propose the shape, agree on it, draw the first mock and iterate visual + shape together, propose additional variants and draw each. The orchestrator (acting as pm) follows the mock-generation rules in `pm.md`. Mocks are real HTML files saved under `docs/ux/<prd-dir>/` and the file path is included in every response for the user to `open`.
- **Phase 1** — PM subagent executes the route: bootstrap / write / extend / refine PRD files, referencing the mocks that already exist from Phase 0.5. No re-discovery, no mock generation here (already done).
- **Phase 2** — Status update: append new CUJ rows (A, B, C) or reset affected rows' Impl/QA/PM columns (D).
- **Phase 3** — Hand off to the user with a truthful summary of what was written, extended, or refined.

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

## Phase 0.5: CUJ shape + mocks — iterative, per CUJ

This is where spec and visual come together. For each CUJ, you (still acting as the pm role in the main thread) iterate the **shape** and the **mocks** with the user in lockstep — propose shape, agree on it, draw the first mock, iterate visual + shape together, propose additional variants. The pm subagent in Phase 1 inherits both: the agreed shapes AND the saved mock files.

This phase is conversational and produces real artifacts (mock files saved to disk). For mock generation rules — file format choice, HTML defaults, iteration discipline, representational elements, visual defaults — **follow the "Mock Generation" section of `pm.md`** verbatim. The agent's rules live there; this skill orchestrates the loop.

For each CUJ, one at a time:

1. **Propose the shape**: title + a one-paragraph description of what happens at a journey level. No full template formatting yet, no acceptance criteria — just the flow in plain prose.
   - **Routes A, B, C** (new CUJs): propose net-new shapes.
   - **Route D** (refining existing CUJs): present the *current* CUJ's shape, then the *revised* shape with a clear "what changed and why" note. Reference the existing CUJ-ID — you're modifying it, not creating a new one.

2. **Iterate on the shape** until the user agrees.

3. **Produce the first mock** for the CUJ's primary state. Save to `docs/ux/<prd-dir>/cuj-<id>-initial.html` (create the directory if needed). **Include the absolute file path in your response** so the user can `open` it. Briefly describe what you drew and what you decided / interpreted; ask an open question for feedback ("What feels off?" / "Does this match what you had in mind?"). Wait for their response.

4. **Iterate on the mock AND the shape together.** Visual feedback often surfaces spec gaps ("if the title is 60 chars, where does it wrap?"). When that happens, update both — re-save the mock with the user-visible file path, and revise the shape in your working memory.

5. **Once the primary state is locked, proactively propose additional variants** — empty state, error state, loading state, long-content overflow, multi-selection, the unhappy path. Don't just produce what the CUJ named — design comprehensively. Ask the user which variants to mock. Then for each agreed variant:
   - Save to `docs/ux/<prd-dir>/cuj-<id>-<state>.html` (where `<state>` is `empty`, `error`, `loading`, etc.)
   - Include the file path in your response
   - Iterate to alignment

6. **For Route D specifically (refining existing CUJs):** before drawing the revised mocks, list the existing mock files under `docs/ux/<prd-dir>/cuj-<id>-*.{html,png,jpg,webp,md}` and ask: "These mocks reflect the prior CUJ — I'll overwrite them with the revised mocks as we agree. OK?" Once confirmed, overwrite as you go. No "flagged for redraw" handoff — the redraw happens here.

7. Move to the next CUJ. Repeat 1–6.

Once all 3-6 CUJ shapes are confirmed AND their mocks are locked, **summarize the set** before moving on:

> Here's the CUJ set we're going to write, with mocks saved at:
> - CUJ-N: <title>   *(new, mocks: cuj-N-initial.html, cuj-N-empty.html)*
> - CUJ-M: <title>   *(refined, was: ...; mocks: cuj-M-initial.html updated, cuj-M-error.html updated)*
> - ...
>
> Ready for me to write the PRD?

Get an explicit "yes" before moving to Phase 1.

---

## Phase 1: Hand off to the `pm` subagent — route-specific PRD writing

The discovery, CUJ-shape iteration, AND mock generation are **done** at this point. The PM subagent's job is narrow and route-specific: bootstrap (A), write new PRD (B), extend existing PRD (C), or refine CUJs in existing PRD (D). It must NOT redo discovery, and it must NOT regenerate mocks — those already exist on disk from Phase 0.5.

Spawn a `pm` subagent with the route + discovery summary + confirmed CUJ shapes + list of mock files embedded in the prompt. Substitute the bracketed sections with your actual collected content:

```
You are executing the PRD-writing phase. Discovery is DONE — do not
re-ask the user about the problem, value prop, scope, form factor,
style, or what the CUJs should be. Mocks are ALREADY produced and
saved on disk — do not regenerate them; reference them by path in
the CUJ template's "Mocks / Reference Designs" section.

## Route: [A | B | C | D]

[Spell out the route in plain English so PM can't misread it:
- A → "Bootstrap brand-new project. No docs/prd/index.md exists yet.
       Create the index AND the first PRD."
- B → "New PRD in existing project. Add a new prd-NNN-<slug>.md
       alongside existing PRDs."
- C → "Extend existing PRD <prd-NNN-<slug>>. Append new CUJ
       sections to that PRD file. Mocks already saved."
- D → "Refine existing CUJs in PRD <prd-NNN-<slug>>. The CUJs
       being refined are: CUJ-<X>, CUJ-<Y>. Modify them in place;
       do NOT create new CUJ IDs. Updated mocks already saved
       (overwriting prior mock files for those CUJ-IDs)."
]

## Discovery summary

[Insert a tight summary of what the discovery conversation established.
For A: target user, primary problem, value prop, MVP scope, form
factor, visual style direction (1-2 paragraphs).
For B: same as A, focused on this PRD's slice of the product.
For C: which host PRD, why the new CUJs fit there, what scope/journey
context they extend.
For D: which CUJs, why they're being refined, what's changing.]

## Confirmed CUJ shapes + mock paths

[For each CUJ:
- The agreed shape (title + paragraph-level flow + any user-added
  specifics: copy strings, edge cases, defaults).
- The list of mock files already saved under docs/ux/<prd-dir>/ for
  this CUJ (e.g., "cuj-1-initial.html, cuj-1-empty.html,
  cuj-1-error.html").
For Route D: include both the OLD shape and the REVISED shape with
the CUJ-ID explicitly stated for each, plus the list of mock files
that were overwritten.]

## Your responsibilities for THIS invocation

### If Route A (bootstrap):

1. Create `docs/prd/index.md` with a product vision section, target
   user section, and an empty PRD listing — using the discovery
   summary above as the source.
2. Expand confirmed CUJ shapes into the full CUJ template format
   (see "format rules" below). The "Mocks / Reference Designs"
   section of each CUJ lists the mock files already saved.
3. Write `docs/prd/prd-000-<slug>.md` (start at 000 for the first PRD).
4. Update `docs/prd/index.md` with this PRD's entry.

### If Route B (new PRD in existing project):

1. Compute NNN: read `docs/prd/index.md`, find the highest existing
   prd-NNN, increment.
2. Expand confirmed CUJ shapes into the full CUJ template format,
   referencing the saved mocks by path.
3. Write `docs/prd/prd-NNN-<slug>.md`.
4. Update `docs/prd/index.md` with the new entry.

### If Route C (extend existing PRD):

1. Read the host PRD file `docs/prd/<host-prd-file>` to determine
   the next available CUJ-ID (highest existing CUJ-ID in this PRD,
   incremented — IDs are unique per PRD).
2. Expand each confirmed CUJ shape into the full CUJ template format,
   referencing the saved mocks by path.
3. **Append** the new CUJ sections to the existing PRD file. Do NOT
   touch existing CUJs in the host PRD.
4. `docs/prd/index.md` does NOT need an entry update — the host PRD
   is already listed.

### If Route D (refine existing CUJs):

1. Read the host PRD file `docs/prd/<host-prd-file>`.
2. For each CUJ being refined (the orchestrator gave you the list of
   CUJ-IDs explicitly), replace its template content with the
   revised shape expanded into the full template format. Preserve
   the CUJ-ID — do NOT create new IDs. Reference the updated mock
   files (already overwritten on disk by the orchestrator in
   Phase 0.5).
3. `docs/prd/index.md` does NOT need an entry update.

### Format rules (apply to all routes):

- **Optional brief research**: WebSearch only if a specific spec
  detail (e.g., a competitor pattern, a standard format) is needed
  to make a CUJ concrete. Do NOT redo a discovery-level research
  pass — the user already knows what they want.
- **Full CUJ template** — exhaustive per CUJ (Context, Preconditions,
  Journey Steps with System Response / User Sees / Details, Edge
  Cases & Error States, Mocks / Reference Designs listing the saved
  files by path, Acceptance Criteria as plain bullets — NOT
  checkboxes).
- The "Mocks / Reference Designs" section lists ONLY mock files that
  actually exist on disk for this CUJ. No `[needs-mocks]` flag —
  that flag no longer exists. If a CUJ has no mocks (rare; means
  the orchestrator skipped mock production in Phase 0.5), state
  "No mocks for this CUJ" with a brief reason.
- Use the confirmed CUJ shape's paragraph as the basis for Journey
  Steps. Do NOT invent CUJs that aren't in the agreed shape set.
- If a shape leaves something genuinely ambiguous, make a defensible
  choice and flag it inline with `(assumption — confirm)`.

Return: a structured summary with these fields so the orchestrator
can build the handoff message:
  - `route`: A | B | C | D (echo what you executed)
  - `files_created`: list of absolute paths created
  - `files_modified`: list of absolute paths modified
  - `cuj_set`: list of "CUJ-<ID>: <title> (new | refined-was-<old-title>)"
```

If `pm` reports a blocker (missing context, contradictory brief, etc.), surface it to the user and stop.

---

## Phase 2: Update `docs/status.md` — route-aware

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

Print a single concise summary that truthfully reflects what was written, extended, refined, or reset. Use the `route` + `files_created` + `files_modified` + `cuj_set` returned by PM in Phase 1, plus the mock paths from Phase 0.5.

### Route A (bootstrap brand-new project):

```
Project bootstrapped.

PRD index:      docs/prd/index.md (created)
PRD written:    docs/prd/prd-000-<slug>.md
Mocks written:  docs/ux/prd-000-<slug>-mockups/  (<count> files; see PRD's Mocks section per CUJ)
Status seeded:  docs/status.md (CUJs added as `not started`)

Next: review the mocks in your browser if you haven't already. When ready,
run /dev-cycle to start building.
```

### Route B (new PRD in existing project):

```
PRD added: docs/prd/prd-NNN-<slug>.md
Mocks written: docs/ux/prd-NNN-<slug>-mockups/  (<count> files)
PRD index updated: docs/prd/index.md
Status updated: <count> new CUJs appended as `not started`

Next: run /dev-cycle to build this feature.
```

### Route C (extend existing PRD):

```
PRD extended: docs/prd/<host-prd-file> (<count> new CUJs appended: <CUJ-IDs>)
Mocks added: docs/ux/<host-prd-mockups-dir>/  (<count> new files for CUJs <CUJ-IDs>)
Status updated: <count> new CUJ rows appended as `not started`

Next: run /dev-cycle to build the new CUJs.
```

### Route D (refine existing CUJs):

```
PRD refined: docs/prd/<host-prd-file> (<count> CUJs revised: <CUJ-IDs>)
Mocks overwritten: docs/ux/<host-prd-mockups-dir>/  (<count> updated files for CUJs <CUJ-IDs>)
Status reset: <count> CUJ rows reset to Impl=`not started`, QA=`—`, PM=`—`

Next: run /dev-cycle. QA will re-walk these CUJs against the revised spec and mocks.
```

Substitute every `<placeholder>` with the actual content from PM's return + the orchestrator's Phase 0.5 records. Do not editorialize — the user has everything they need.

## What NOT to do

- **Don't rush Phase 0.** Discovery in the main thread exists so you can have a real, multi-turn product design conversation. If you ask 2 questions and start drafting CUJs, you've failed the user. Stay in discovery until you can describe the user, problem, value prop, scope, and journey set *in your own words* — not just parrot back what the user said.
- **Don't use `AskUserQuestion` during Phase 0 discovery.** Free-form text dialogue is the whole point. `AskUserQuestion` is fine for menu choices elsewhere; it's the wrong tool for design conversation.
- **Don't draft CUJ shapes or mocks in Phase 0.** Build the picture first. Phase 0.5 is where shapes AND mocks land.
- **Don't skip Phase 0.5's mock iteration.** Producing the spec without the visual is exactly the asynchronous-handoff failure mode this skill replaced. For every CUJ, the primary mock must be drawn, iterated, and locked before moving on.
- **Don't bulk-produce mocks.** One mock per response. Save it; include the absolute file path; describe what you drew; ask for feedback; wait. Bulk = no iteration = the rigidity we eliminated.
- **Don't forget to include the file path** in every mock-save response. The user shouldn't have to hunt for "where did you save it?" — give them a path they can `open` directly.
- **Don't default to image mocks (PNG/JPG) when HTML would work.** HTML iterates; images don't. See `pm.md` Mock Generation section for when image formats actually fit.
- **Don't have the PM subagent re-do discovery in Phase 1.** Phase 1's prompt embeds the discovery summary, the confirmed CUJ shapes, AND the mock file paths. PM writes the PRD referencing what already exists — no re-design, no re-mocking.
- **Don't have the PM subagent regenerate mocks in Phase 1.** Mocks are already saved on disk from Phase 0.5. PM only references them by path in the CUJ template's "Mocks / Reference Designs" section.
- **Don't include the `[needs-mocks]` flag in CUJs you write.** That flag no longer exists — mocks are produced inline during design, so every CUJ has its mocks at write time. (If a CUJ legitimately can't have mocks — e.g., a backend-only CUJ — state "No mocks for this CUJ" with a brief reason.)
- **Don't reference `docs/ux/README.md`, `MOCK_BRIEF.md`, or "Claude Desktop" anywhere.** The async-handoff flow is gone. Mocks live in `docs/ux/<prd-dir>/cuj-*.{html,...}`; that's it.
- **Don't write the PRD yourself in the orchestrator.** Phase 1 PM subagent owns the file writes. You own the conversation, the shapes, the mocks, and the handoff.
- **Don't skip the routing decision in Phase 0.** A pitch that should extend an existing PRD must NOT become a new PRD just because writing a new file is mechanically simpler. Wrong routing fragments features across PRDs and confuses the planner downstream.
- **For Route D: don't try to preserve old mocks alongside revised ones.** When the user confirms refinement and you redraw the affected mocks in Phase 0.5, you overwrite the prior files at the same paths. Mock-file paths are stable identifiers (`cuj-<id>-<state>.html`); the file content evolves.
