#### For web apps/services:

You MUST drive a real browser. Antigravity exposes browser control through the **`/browser`** subagent — invoke it for each CUJ. If browser tooling is unavailable (extension not installed, browser tools disabled in settings), do NOT downgrade to reading HTML or guessing — set the affected CUJ verdicts to `BLOCKED_NO_CAPABILITY`, FAIL the gate, and tell the user to install the Antigravity Chrome extension and enable browser tools.

For each CUJ in scope, walk the journey programmatically:

1. **Start the dev server** with `run_command` (e.g., `npm run dev &`, `yarn dev &`). Capture the URL.
2. **Delegate to the browser subagent** by invoking `/browser`. Hand it a self-contained brief that includes:
   - The entry URL from the CUJ Preconditions.
   - The verbatim "Journey Steps" from the CUJ spec.
   - The verbatim "Edge Cases & Error States" list.
   - These explicit instructions to the subagent:
     - Navigate to the URL and capture the initial state (screenshot + DOM/markdown snapshot).
     - Execute every Journey Step in order — click, type, navigate, select, hover, drag, handle dialogs, upload as required.
     - After each step, take a screenshot and record the observed System Response and what the user sees.
     - Walk every Edge Case & Error State separately, with its own screenshots.
     - Capture browser console messages — any error-level entry is a finding.
     - Save all artifacts (screenshots, video recording) under `docs/qa-artifacts/<iteration>/<cuj-id>/` with descriptive filenames (`00-initial.png`, `<NN>-<step-slug>.png`, `edge-<N>-<slug>.png`).
3. **Read the returned Artifacts** — screenshots, video, console logs. These are the evidence; do not paraphrase, cite the file paths in your report.
4. **Verify** every "User sees" assertion from the spec against the subagent's reported observations and screenshots — not against your reading of the source code.
5. **Stop the dev server**.

**Per-CUJ requirements that gate PASS:**
- The browser subagent must have produced at least one screenshot per Journey Step under `docs/qa-artifacts/<iteration>/<cuj-id>/`. Zero artifacts = `NO_EVIDENCE` (= FAIL).
- Console-message log captured (even if empty); error-level entries logged as findings.
- Every "User sees" assertion verified against the subagent's reported observations or screenshot inspection.
