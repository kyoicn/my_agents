---
name: "new-project"
description: "Bootstrap a new project — collect a product brief, drive PRD/CUJ design via the pm agent, write a MOCK_BRIEF.md for Claude Desktop to consume for mock production, and seed docs/ux/README.md with the one-time Claude Desktop Project setup."
---

<!-- generated-from: claude/commands -->

# new-project

Use this skill when the user asks to run `new-project`.

## Command Template

# new-project — Kick off a fresh PRD

You are the orchestrator for starting a new project. Drive the brief intake, hand off to the `pm` agent for PRD design, and produce a clean handoff artifact for Claude Desktop to consume when drawing mocks.

This skill works in two scenarios:
- **First PRD in the project** — bootstraps `docs/prd/index.md`, `docs/design/system.md` (stub), and `docs/ux/README.md`.
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

1. **Bootstrap missing scaffolding**: 
   - If `docs/prd/index.md` does not exist, create it with a product
     vision section, target user section, and an empty PRD listing.
   - If `docs/design/system.md` does not exist, create a stub with
     tech-stack TBD placeholders (the tl agent will fill it later).

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

   1. If you have not yet set up the Claude Desktop "UX Mocks"
      Project, see `docs/ux/README.md` in this repo for one-time
      setup instructions.
   2. Open a new conversation inside your Claude Desktop "UX Mocks"
      Project.
   3. Paste this entire file into the first message.
   4. Claude Desktop will produce one HTML per response. Save each
      into `docs/ux/prd-NNN-<slug>-mockups/` using the exact filename.
   5. When all mocks are saved, return to Claude Code and run
      `/dev-cycle` to start iteration 1.
   ```

   Fill in every <placeholder> with the actual content from the PRD
   you just wrote. Do not leave any placeholder text in the final file.

Return: a short summary listing every file you created or modified
(absolute paths preferred), and a one-line description of the CUJ
set you drafted.
```

If `pm` reports a blocker (missing context, contradictory brief, etc.), surface it to the user and stop.

## Phase 2: Seed `docs/ux/README.md` (one-time per repo)

If `docs/ux/README.md` does **not** exist, write it now. This file gives the user the one-time Claude Desktop Project setup instructions; subsequent `/new-project` invocations skip this phase.

Write the following content verbatim:

````markdown
# UX Mocks — handoff convention

This directory holds visual mocks for each PRD's CUJs. Mocks are produced in **Claude Desktop**, not by any agent in this repo — agents are bad at iterative visual design; Claude Desktop's chat interface is fast for polishing.

## Folder layout

```
docs/ux/
├── README.md                              ← you are here
├── prd-NNN-<slug>-mockups/
│   ├── MOCK_BRIEF.md                      ← handoff doc, written by pm via /new-project
│   ├── cuj-1-initial.html
│   ├── cuj-1-after-action.html
│   ├── cuj-2-empty.html
│   └── ...
└── ...
```

QA discovers mocks by globbing `docs/ux/**/cuj-<id>-*.{html,png,jpg,webp,md}` — you do not need to register new mocks anywhere.

## One-time setup: Claude Desktop "UX Mocks" Project

1. Open Claude Desktop → Projects → "New Project".
2. Name it **UX Mocks**.
3. Paste the following into the Project's **Custom Instructions**:

   > You are a UX designer producing HTML mocks for a developer workflow.
   >
   > When the user pastes a MOCK_BRIEF.md:
   > - Read every visual state listed.
   > - For each state, produce a self-contained `.html` file. Tailwind via CDN is fine. No JS unless interactivity itself is the mock's point.
   > - Files must be named `cuj-<id>-<state>.html` exactly.
   > - Show me each one rendered before moving to the next.
   > - After each, ask: "polish, next, or revise?"
   >
   > Visual style defaults: clean, modern, neutral palette, generous whitespace, 14–16px body text, system font stack. Override only when the MOCK_BRIEF specifies otherwise.
   >
   > Output one HTML per response inside a ```html fenced block so it is easy to copy back into the repo.

4. Done. You only set this up once. Reuse it for every project.

## Workflow per PRD

1. In Claude Code: `/new-project` (this writes `MOCK_BRIEF.md` for you).
2. Open the new `docs/ux/prd-NNN-<slug>-mockups/MOCK_BRIEF.md`.
3. Paste it into a new conversation in your Claude Desktop **UX Mocks** Project.
4. Save each HTML response into this directory using the exact filename Claude Desktop names it.
5. Back in Claude Code: `/dev-cycle` — QA will discover the mocks automatically.
````

## Phase 3: Final handoff to the user

After Phase 1 and Phase 2 complete, print a single concise summary to the user:

```
PRD written: docs/prd/prd-NNN-<slug>.md
Mock brief: docs/ux/prd-NNN-<slug>-mockups/MOCK_BRIEF.md
Mockups dir: docs/ux/prd-NNN-<slug>-mockups/

Next steps:
1. (First time only) Set up your Claude Desktop "UX Mocks" Project — see docs/ux/README.md.
2. Open the MOCK_BRIEF.md above and paste it into a new conversation in that Project.
3. Save each generated HTML into the mockups dir.
4. Run /dev-cycle to start iteration 1.
```

Substitute the actual paths. Do not editorialize — the user has everything they need.

## What NOT to do

- **Don't write the PRD yourself** — delegate every CUJ decision to the `pm` agent. The `pm` agent owns the CUJ template, the interactive discussion with the user, and the writing.
- **Don't draw mocks** — the entire point of MOCK_BRIEF.md is to hand mock production off to Claude Desktop. Do not generate HTML mocks from this skill or from any agent in this repo.
- **Don't overwrite an existing `docs/ux/README.md`** — only create it if missing. Subsequent `/new-project` runs skip Phase 2.
- **Don't skip the visual style question in Phase 0** — even "no preference" is a valid answer that gets captured in the MOCK_BRIEF as "use defaults". The designer needs to know they have latitude.
- **Don't run `/dev-cycle` automatically after this** — the user produces mocks first; rushing into implementation defeats the visual-fidelity flow.
