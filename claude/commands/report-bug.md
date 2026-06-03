---
description: File a bug report into docs/issues.md with optional screenshots. Acknowledges that attached images in chat can be seen (multimodal) but not extracted to disk; offers clipboard via pngpaste, an explicit file path, interactive screencapture, or skip. Writes screenshots to docs/issues-attachments/ (auto-gitignored). Optionally chains into /triage.
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

1. **Description** — one-line summary + optional longer detail. Push back on vague: "the dropdown is broken" then "broken how? doesn't open? opens but doesn't filter? shows wrong items?"

2. **Where (CUJ relevance)** — skim `docs/prd/` for plausible CUJs based on the description and propose a candidate: "Sounds like CUJ-3 in prd-002-articles — that's the article-listing journey. Match?" If nothing obvious, ask for a hint (which page/screen/CLI command) or accept `unknown`.

3. **Expected vs Observed** — explicit, concrete. Push back on vague answers the same way `/design-feature` does in discovery.

4. **Repro steps** — only if not obvious from the description. Skip cleanly for purely visual/cosmetic bugs ("just look at the screenshot is enough").

5. **Screenshots** — see Phase 2.

After collection, briefly summarize back and ask "ready to file?" before writing the entry. Don't lock in until the user confirms.

## Phase 2: Screenshot intake

**Honesty up front about tool limits.** When the user attaches an image to the message that invokes `/report-bug`, you can *see* the image — use it freely to enrich the description in Phase 3 — but you **cannot directly extract its bytes to disk** with any available tool. To save the image to `docs/issues-attachments/`, you need either (a) the image still on the system clipboard, (b) an explicit file path on disk from the user, or (c) a fresh capture taken now.

Tell the user this plainly when relevant. **Do NOT scan the filesystem** (no `find`, no `mdfind`, no broad globs of `~/Library/...` or `/tmp/`) — those are invasive, slow, and unreliable for guessing which file matches an attached image.

The intake paths, in order:

### 2a. Try clipboard once (single command, non-invasive)

If you suspect the screenshot may be on the clipboard — e.g., the user just took one with Cmd+Ctrl+Shift+4 (screen-to-clipboard shortcut), or they pasted into the chat with Cmd+V — try:

```bash
pngpaste docs/issues-attachments/<issue-id>-N.png 2>/dev/null
[ -s docs/issues-attachments/<issue-id>-N.png ] && echo "OK" || rm -f docs/issues-attachments/<issue-id>-N.png
```

- If a non-empty file lands, you got it. Done.
- If pngpaste isn't installed (`command not found`), surface once: "`pngpaste` isn't installed — `brew install pngpaste` enables the fastest clipboard path. Falling through."
- If the clipboard had no image (0-byte file or non-zero exit), silently fall through to 2b. Don't keep the empty file around.

This is the **only** automatic attempt. If 2a misses, ask the user.

### 2b. Ask the user explicitly how to save the image

If 2a didn't capture anything but the user clearly intended a screenshot (attached an image, said "see attached," described a visual bug, etc.), present three explicit choices in plain text:

> I can see the image you attached, but I can't extract it from chat directly — that's a tool limit. Pick one:
>
> 1. **File path** — if you dragged the image in from Finder, tell me the absolute path. I'll `cp` it in.
> 2. **Take a fresh capture now** — I'll run `screencapture -i` and you can drag a region or click a window.
> 3. **Skip** — file the bug without a screenshot. The description + multimodal context I can already see is often enough.

Wait for the answer.

### 2c. "File path" → copy from disk

`cp "<provided-path>" docs/issues-attachments/<issue-id>-N.png`. Then verify file size > 0; if zero, the source was bad — tell the user and re-ask.

### 2d. "Take a fresh capture" → screencapture

```bash
screencapture -i docs/issues-attachments/<issue-id>-N.png
```

Blocks until the user finishes the selection (or hits Esc to cancel). On cancel, the file won't exist — re-ask or move on.

### 2e. "Skip" → no screenshot

That's fine. Many bugs don't need one (logic bugs, CLI bugs, data bugs). The multimodal context from the in-chat attachment (if any) can still inform the issue body you write in Phase 3.

---

After each successful save (2a, 2c, or 2d), **read the saved file** with the Read tool to get a multimodal view of what landed on disk (which may differ from the in-chat attachment if the user picked a different file). Use what you see to enrich the issue body — even if the user gave a one-line description, you can add visual specifics like "screenshot shows the dropdown rendering off-screen below the viewport with truncated 'Lo...' text visible." That makes the report immediately useful to `/triage` later.

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

- **Don't scan the filesystem looking for the attached image.** `find`, `mdfind`, and broad globs over `~/Library` or `/tmp` are invasive and unreliable. Use Phase 2's clipboard-try-once, then ask the user.
- **Don't commit screenshots.** Phase 0 ensures `.gitignore` excludes `docs/issues-attachments/`. Never `git add` files from that directory.
- **Don't skip the gitignore check.** Even on the second run when the dir exists, verify the gitignore line is present on every invocation — cheap, prevents accidental commits if the user pulled a fresh checkout.
- **Don't write incomplete entries.** Description + CUJ-or-unknown + Expected + Observed are required. Screenshots and Repro are optional.
- **Don't fail silently on missing tooling.** If pngpaste isn't installed, say so once and offer the alternative — don't just skip to manual path quietly.
- **Don't loop indefinitely on screenshots.** Two paths to escape the screenshot phase: user says "skip" or user confirms "no more." Stop there.
- **Don't pre-triage.** Stay out of root-cause analysis, scope assessment, or fix recommendations. That's `/triage`'s job. Your job is faithful intake.
