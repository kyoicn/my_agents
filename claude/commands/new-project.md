---
description: Bootstrap a new project — collect a product brief, drive PRD/CUJ design via the pm agent, write a MOCK_BRIEF.md for an external designer agent to consume, and seed docs/ux/README.md with the designer's operating rules.
---

# new-project — Kick off a fresh PRD

You are the orchestrator for starting a new project. Drive the brief intake, hand off to the `pm` agent for PRD design, and produce a clean handoff artifact for Claude Desktop to consume when drawing mocks.

This skill works in two scenarios:
- **First PRD in the project** — bootstraps `docs/prd/index.md` and `docs/ux/README.md`.
- **Subsequent PRDs** — adds the new PRD alongside existing ones, only writes files that don't yet exist.

## Phase 0: Collect the product brief

If the user invoked `/new-project <freeform pitch>`, use that as a seed for the brief.

Use `AskUserQuestion` to collect any missing fields. The brief is a small structured record:

- **Product name** (short, memorable — used as the slug)
- **One-line pitch** (what is it, who it's for, why it exists)
- **Target user** (who, what context)
- **Primary problem** (the pain point this addresses)
- **Form factor** (web desktop / mobile web / both / native — affects mock width and interactions)
- **Visual style preference** (free text — e.g., "minimal modern", "playful", or "no preference, use defaults")

Hold the brief in your working memory. Do not write any files yet — `pm` will do that after the design conversation lands.

If the user already has a `docs/prd/index.md` with a product vision that contradicts the brief (e.g., they're trying to start a "new project" inside an existing project's repo), stop and ask whether they meant to add a new PRD to the existing project or actually start a separate repo.

## Phase 1: Drive PRD design via the `pm` agent

Spawn a `pm` subagent with the brief embedded in the prompt. Use this prompt (substitute `<brief>` with the structured brief from Phase 0):

```
You are designing the PRD for a project. Here is the brief:

<brief>

Your responsibilities for THIS invocation:

1. **Bootstrap missing PRD scaffolding**: if `docs/prd/index.md` does
   not exist, create it with a product vision section, target user
   section, and an empty PRD listing.

2. **Research**: WebSearch for prior art, competitors, and patterns
   relevant to this product domain. Cite findings briefly.

3. **Draft 3-6 initial CUJs** using your full CUJ template — be
   exhaustive per CUJ (Context, Preconditions, Journey Steps with
   System Response / User Sees / Details, Edge Cases & Error States,
   Mocks / Reference Designs section with [needs-mocks] flag,
   Acceptance Criteria).

4. **Discuss the draft CUJs with the user**, iterate until aligned.

5. After alignment, write the final files:
   - `docs/prd/prd-NNN-<slug>.md` (NNN is the next sequential PRD
     number; <slug> is the product-name kebab-cased)
   - Update `docs/prd/index.md` with a new entry

6. **ALSO write `docs/ux/prd-NNN-<slug>-mockups/MOCK_BRIEF.md`** — a
   self-contained handoff document for the Claude Desktop "UX Mocks"
   Project. Use this exact structure:

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

Return: a short summary listing every file you created or modified
(absolute paths preferred), and a one-line description of the CUJ
set you drafted.
```

If `pm` reports a blocker (missing context, contradictory brief, etc.), surface it to the user and stop.

## Phase 2: Seed `docs/ux/README.md` (one-time per repo)

If `docs/ux/README.md` does **not** exist, write it now. This file is the **operating rules** for the designer agent — whichever agent (typically Claude Desktop with filesystem access) is producing mocks reads this directly. Subsequent `/new-project` invocations skip this phase.

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
│   ├── MOCK_BRIEF.md                      ← per-PRD spec, written by /new-project
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

## Phase 2.5: Seed `docs/status.md` with the new CUJs

`docs/status.md` is the canonical per-CUJ progress doc. It must exist from day 0 so the user (and the loop's agents) always have one place to answer "where are we?". Run this phase **after** Phase 1 wrote the PRD.

Spawn a `status` subagent:

```
Prompt: "Refresh docs/status.md. A new PRD was just written
(docs/prd/prd-NNN-<slug>.md, substitute the actual path); every CUJ
in it starts with Impl=`not started`, QA=`—`, PM=`—` since no code
or verification exists yet. If docs/status.md already exists (because
this is a second PRD added to an existing project), preserve all
existing rows and append rows for the new CUJs only. Follow your
Section 4 template exactly. Do not commit."
```

The status agent handles the working-language detection and the table structure. After it returns, verify `docs/status.md` lists every CUJ from the new PRD.

---

## Phase 3: Final handoff to the user

After Phase 1 and Phase 2 complete, print a single concise summary to the user:

```
PRD written: docs/prd/prd-NNN-<slug>.md
Mock brief: docs/ux/prd-NNN-<slug>-mockups/MOCK_BRIEF.md
Mockups dir: docs/ux/prd-NNN-<slug>-mockups/
Status seeded: docs/status.md (CUJs from this PRD added as `not started`)

To produce mocks, open a chat agent with filesystem access to this
repo and send:

  Please produce mocks for this PRD. First read docs/ux/README.md
  for your designer rules, then read docs/ux/prd-NNN-<slug>-mockups/
  MOCK_BRIEF.md. Produce one HTML at a time per the rules and save
  each into docs/ux/prd-NNN-<slug>-mockups/.
```

Substitute the actual paths. Do not editorialize — the user has everything they need.

## What NOT to do

- **Don't write the PRD yourself** — delegate every CUJ decision to the `pm` agent. The `pm` agent owns the CUJ template, the interactive discussion with the user, and the writing.
- **Don't draw mocks** — the entire point of MOCK_BRIEF.md is to hand mock production off to Claude Desktop. Do not generate HTML mocks from this skill or from any agent in this repo.
- **Don't overwrite an existing `docs/ux/README.md`** — only create it if missing. Subsequent `/new-project` runs skip Phase 2.
- **Don't skip the visual style question in Phase 0** — even "no preference" is a valid answer that gets captured in the MOCK_BRIEF as "use defaults". The designer needs to know they have latitude.
