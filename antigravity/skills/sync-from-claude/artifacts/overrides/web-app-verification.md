#### For web apps/services:

You MUST drive a real browser. Antigravity exposes browser control through the **`/browser`** subagent — invoke it for each CUJ. If browser tooling is unavailable (extension not installed, browser tools disabled in settings), do NOT downgrade to reading HTML or guessing — set the affected CUJ Results to `BLOCKED`, FAIL the gate, and tell the user to install the Antigravity Chrome extension and enable browser tools.

**Every CUJ is walked TWICE** to detect flakiness. The two walks are independent: invoke `/browser` once for each walk so the subagent uses a fresh browser session each time. Compare results — see "Flakiness handling" below.

For each CUJ in scope, perform two independent walks (`run1`, `run2`). Each walk:

1. **Start (or restart) the dev server** with `run_command` (e.g., `npm run dev &`, `yarn dev &`). Capture the URL. (You may reuse the same dev server across runs; you must invoke `/browser` separately for each run so the subagent uses a fresh browser session.)
2. **Delegate to the browser subagent** by invoking `/browser`. Hand it a self-contained brief that includes:
   - The entry URL from the CUJ Preconditions.
   - The verbatim "Journey Steps" from the CUJ spec.
   - The verbatim "Edge Cases & Error States" list.
   - The run label (`run1` or `run2`) so artifacts are organized accordingly.
   - These explicit instructions to the subagent:
     - Navigate to the URL and capture the initial state (screenshot + DOM/markdown snapshot).
     - Execute every Journey Step in order — click, type, navigate, select, hover, drag, handle dialogs, upload as required.
     - After each step, take a screenshot and record the observed System Response and what the user sees.
     - Walk every Edge Case & Error State separately, with its own screenshots.
     - Capture browser console messages — any error-level entry is a finding.
     - Save all artifacts (screenshots, video recording) under `docs/qa-artifacts/<iteration>/<cuj-id>/<run>/` with descriptive filenames (`00-initial.png`, `<NN>-<step-slug>.png`, `edge-<N>-<slug>.png`).
3. **Read the returned Artifacts** — screenshots, video, console logs. These are the evidence; do not paraphrase, cite the file paths in your report.
4. **Verify** every "User sees" assertion from the spec against the subagent's reported observations and screenshots — not against your reading of the source code.
5. **Stop the dev server** after the second run.

**Visual fidelity comparison against mocks (per Journey Step, both runs):**

Mocks live under `docs/ux/<prd-dir>/cuj-<id>-<state>.<ext>` (your PM may follow a slightly different folder layout — discover by globbing `docs/ux/**/cuj-<id>-*.{html,png,jpg,webp,md}`).

1. For each CUJ, use `list_dir` / `grep_search` to find files matching `docs/ux/**/cuj-<id>-*.{html,png,jpg,webp,md}`.
2. If zero matches → log `Mocks: NO_MOCK` for this CUJ in the report. Skip fidelity comparison; continue with functional verification only. (Result is unaffected; this is a label, not a failure.)
3. If matches exist, include them in your `/browser` brief and instruct the subagent to dispatch by extension:
   - **`.html`** — open the mock in a separate tab via `file://<absolute mock path>`. Screenshot both the mock tab and the implementation. Save both as `docs/qa-artifacts/<iteration>/<cuj-id>/<run>/<NN>-step-live.png` and `<NN>-step-mock.png`. Compare side-by-side — check layout, spacing, colors, copy, element presence, hierarchy.
   - **`.png` / `.jpg` / `.webp`** — read the mock image directly and compare against the Journey Step screenshot using the same visual checks.
   - **`.md`** — read the markdown and treat each statement as an additional textual acceptance criterion; verify each against observed behavior.
4. Any deviation between implementation and mock is logged as a finding with kind `VISUAL_DEVIATION` and a severity that reflects impact:
   - `[LOW][VISUAL_DEVIATION]` — minor cosmetic gap (2px misalignment, slightly different shade, swapped icon).
   - `[MEDIUM][VISUAL_DEVIATION]` — noticeable layout difference, wrong typography, missing decorative element.
   - `[HIGH][VISUAL_DEVIATION]` — primary action button absent or in wrong place, navigation structure wrong, content hierarchy reversed.
   - `[CRITICAL][VISUAL_DEVIATION]` — entire screen layout wrong, page renders unusable, copy completely different from mock.
5. Visual deviations are treated as bugs identical to any other — they roll up into the overall verdict the same way, and dev-cycle Phase 4 applies its loop rules to them by severity.

**Flakiness handling — comparing the two runs:**
- For each Journey Step and Edge Case, compare the per-step outcome between `run1` and `run2`.
- **Both PASS** → step Result is `PASS`. No finding.
- **Both FAIL** → step Result is `FAIL`. Log a bug with kind `BUG` (or `REGRESSION`/`FABRICATION` if it fits the archetypes).
- **One PASS, one FAIL** → step Result is `FAIL` (be pessimistic — the step is unreliable, so it cannot be trusted). Log a bug with kind `FLAKY`, severity based on impact (a flaky payment submission is HIGH/CRITICAL; a flaky tooltip is LOW). Include both screenshots in the report so the inconsistency is visible.
- The CUJ-level Result rolls up from its steps: any step `FAIL` → CUJ `FAIL`; otherwise `PASS`.

**Per-CUJ requirements that gate the Result:**
- Both `run1` and `run2` artifact dirs exist with at least one screenshot per Journey Step. Missing artifacts for any step → that step Result is `NOT_RUN`, CUJ Result is `FAIL`.
- Console-message log captured per run (even if empty); error-level entries logged as findings.
- Every "User sees" assertion verified against the subagent's reported observations or screenshot inspection.
