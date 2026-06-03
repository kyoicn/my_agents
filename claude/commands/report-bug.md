---
description: File a bug report into docs/issues.md with optional screenshots. Handles screenshot intake from drag-attached images (multimodal), clipboard via pngpaste, interactive screencapture, or a file path. Writes screenshots to docs/issues-attachments/ (auto-gitignored). Optionally chains into /triage.
---

# report-bug — File a bug into the inbox

You are filing a bug report. The output is one h3-block entry in `docs/issues.md` plus any screenshots saved to `docs/issues-attachments/`.

This skill owns **intake only**. Diagnosis is `/triage`; fixing is `/quick-fix` or `/dev-cycle`. The skill optionally chains into `/triage` at the end.

## Phase 0: Setup

1. Generate the **issue ID** — local timestamp in filesystem-safe form. Run:
   ```bash
   date "+%Y-%m-%d-%H-%M-%S"
   ```
   This is the unique ID for this report (e.g., `2026-06-03-14-30-25`). Reuse it for every screenshot filename in this invocation.

2. Generate the **filed timestamp** in human-readable form (used in the issue body). Run:
   ```bash
   python3 -c "from datetime import datetime as d; t=d.now().astimezone(); m=int(t.utcoffset().total_seconds()//60); s='+' if m>=0 else '-'; h,mm=divmod(abs(m),60); o=f'{h}:{mm:02d}' if mm else str(h); print(t.strftime('%Y-%m-%d %H:%M:%S')+f' (UTC{s}{o})')"
   ```

3. Ensure `docs/issues-attachments/` exists:
   ```bash
   mkdir -p docs/issues-attachments
   ```

4. Ensure `.gitignore` excludes the attachments dir. If `.gitignore` doesn't exist or doesn't contain a line for `docs/issues-attachments/`, append it. The screenshots must not be committed.

## Phase 1: Collect the report

If the user invoked `/report-bug <freeform description>`, use that as the seed for the description. Otherwise open with: "What's broken? Describe it in a sentence or two."

**No `AskUserQuestion`** — this is conversational, like discovery in `/design-feature`. Free-form text Q&A, one or two questions per turn, react to answers.

Collect in this order, building the structured report progressively:

1. **Description** — one-line summary + optional longer detail. Push back on vague: "the dropdown is broken" → "broken how? doesn't open? opens but doesn't filter? shows wrong items?"

2. **Where (CUJ relevance)** — skim `docs/prd/` for plausible CUJs based on the description and propose a candidate: "Sounds like CUJ-3 in prd-002-articles — that's the article-listing journey. Match?" If nothing obvious, ask for a hint (which page/screen/CLI command) or accept `unknown`.

3. **Expected vs Observed** — explicit, concrete. Push back on vague answers the same way `/design-feature` does in discovery.

4. **Repro steps** — only if not obvious from the description. Skip cleanly for purely visual/cosmetic bugs ("just look at the screenshot is enough").

5. **Screenshots** — see Phase 2.

After collection, briefly summarize back and ask "ready to file?" before writing the entry. Don't lock in until the user confirms.

## Phase 2: Screenshot intake

Multiple paths. **Always try these in order**, falling through if a path doesn't yield a screenshot:

### 2a. Drag-attached image in this conversation

If the user attached an image when invoking `/report-bug` (visible to you as multimodal context), you can see it but cannot directly extract bytes via tools. Try to find it on disk by globbing Claude Code's recent cache:

```bash
# Try candidate cache locations for images created in the last 5 minutes
find ~/Library/Caches -name "*.png" -mmin -5 2>/dev/null | head -20
find ~/Library/Application\ Support/Claude -name "*.png" -mmin -5 2>/dev/null | head -20
find /tmp -maxdepth 2 -name "*.png" -mmin -5 2>/dev/null | head -20
```

If the glob returns candidates, present them to the user with sizes and timestamps and ask "is this the screenshot you attached?". If confirmed, `cp` it into `docs/issues-attachments/<issue-id>-N.png`. If multiple matches, ask user to pick.

If no candidate is found OR the user says "that's not it" → fall through to 2b. Tell the user briefly what you tried and what's next: "I can see the image you attached but couldn't locate it on disk. Easiest fix: take a fresh screenshot to clipboard with Ctrl+Cmd+Shift+4, then I'll grab it from there."

### 2b. Clipboard via pngpaste

```bash
pngpaste docs/issues-attachments/<issue-id>-N.png
echo $?
```

If pngpaste isn't installed, the exit code will be non-zero with `command not found`. Surface:

> `pngpaste` not installed. For fastest clipboard screenshots install it:
>   `brew install pngpaste`
>
> Or I can capture a new screenshot interactively instead (Phase 2c).

Fall through to 2c.

If pngpaste runs but the clipboard had no image, it produces a 0-byte file or errors. Check the file size:
```bash
[ -s docs/issues-attachments/<issue-id>-N.png ] && echo "OK" || rm docs/issues-attachments/<issue-id>-N.png
```

### 2c. Interactive screencapture

macOS-native, always available, lets the user select a region or window right now:

```bash
screencapture -i docs/issues-attachments/<issue-id>-N.png
```

This blocks until the user finishes the selection (or hits Esc to cancel). On cancel, the file won't exist — check before adding it to the issue body.

### 2d. Manual file path

If 2a/2b/2c didn't work or the screenshot the user wants is already saved elsewhere, ask for a path. `cp` it into `docs/issues-attachments/<issue-id>-N.png`.

### 2e. Skip

No screenshot. That's fine — many bugs don't need one (logic bugs, CLI bugs, data bugs).

---

After each successful screenshot capture (any of 2a-2d), **read the saved file** with the Read tool to get a multimodal view of it. Use what you see to enrich the issue body — even if the user gave a one-line description, you can add visual specifics like "screenshot shows the dropdown rendering off-screen below the viewport with truncated 'Lo...' text visible." This makes the report immediately useful to `/triage` later.

After each screenshot, ask: "Got it. Another screenshot? (y/n)" — increment the suffix (`-1`, `-2`, ...) for each.

## Phase 3: Write the entry

Append to `docs/issues.md`. If `docs/issues.md` does not exist, create it with this preamble first:

```markdown
# Issues

Lightweight intake queue. Each issue is an h3 block with structured fields. Removed when resolved (history lives in git via fix: commits).

---
```

Then append the new block (preceded by a `---` separator and a blank line):

```markdown
---

### Issue <issue-id>: <one-line summary>

- **Filed**: <human-readable timestamp from Phase 0>
- **Description**: <multi-line description; one paragraph is fine>
- **CUJ**: CUJ-<ID> (<prd-file>) | unknown
- **Expected**: <expected behavior>
- **Observed**: <observed behavior>
- **Repro**: <numbered steps, or "—" if not applicable>
- **Screenshots**:
  - docs/issues-attachments/<issue-id>-1.png
  - docs/issues-attachments/<issue-id>-2.png

  (or omit the **Screenshots** field entirely if there are none)
```

The `Triage` field is added later by `/triage` — do not include a placeholder for it now.

## Phase 4: Optionally chain to /triage

After writing the entry, ask: "Filed as Issue `<issue-id>`. Run /triage on it now? (y/n)"

- If yes → invoke `/triage <issue-id>` (the orchestrator passes the ID; triage looks up the block).
- If no → print the issue ID one more time as a parting reference and stop.

## What NOT to do

- **Don't commit screenshots.** Phase 0 ensures `.gitignore` excludes `docs/issues-attachments/`. Never `git add` files from that directory.
- **Don't skip the gitignore check.** Even if it's the second run and the dir exists, verify the gitignore line is present on every invocation — cheap, prevents accidental commits if the user pulled a fresh checkout.
- **Don't write incomplete entries.** Description + CUJ-or-unknown + Expected + Observed are required. Screenshots and Repro are optional.
- **Don't fail silently on missing tooling.** If pngpaste isn't installed, say so and offer the alternative — don't just skip to manual path quietly.
- **Don't loop indefinitely on screenshots.** Two paths to escape the screenshot phase: user says "skip" or user confirms "no more." Stop there.
- **Don't pre-triage.** Stay out of root-cause analysis, scope assessment, or fix recommendations. That's `/triage`'s job. Your job is faithful intake.
