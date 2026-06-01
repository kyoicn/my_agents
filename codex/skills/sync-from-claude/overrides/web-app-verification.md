#### For web apps/services:

You MUST drive a real browser via Codex's bundled `@browser` plugin, executed through the Node REPL JavaScript tool (`mcp__node_repl__js`). If browser tooling is unavailable, follow the **Prerequisites** section above — do not improvise.

**Every CUJ is walked TWICE** to detect flakiness. The two walks are independent: close the tab between them and re-open a fresh one. Compare results — see "Flakiness handling" below.

##### One-time per Node REPL session: browser-runtime setup

Run this idempotent setup cell once per session via `mcp__node_repl__js`. Discover the plugin's absolute path from `~/.codex/plugins/cache/openai-bundled/browser/<version>/scripts/browser-client.mjs` — do not guess the path.

```js
if (!globalThis.agent) {
  const { setupBrowserRuntime } = await import("<absolute path>/browser-client.mjs");
  await setupBrowserRuntime({ globals: globalThis });
}
if (!globalThis.browser) {
  globalThis.browser = await agent.browsers.get("iab");
}
await browser.nameSession("🧪 qa-cuj-<id>-<run>");
```

##### Per walk (perform for `run1`, then again for `run2`)

1. **Start (or restart) the dev server** with `run_command` (e.g., `npm run dev &`). Capture the URL. You may reuse the dev server across both runs, but you MUST use a fresh tab per run.

2. **Open a fresh tab and navigate** via `mcp__node_repl__js`:
   ```js
   let tab = await browser.tabs.new();
   await tab.goto("<entry URL from CUJ Preconditions>");
   await tab.playwright.waitForLoadState({ state: "domcontentloaded", timeoutMs: 10000 });
   ```

3. **Capture initial state** — save a screenshot and grab a DOM snapshot:
   ```js
   const fs = await import("node:fs/promises");
   const dir = `docs/qa-artifacts/<iteration>/<cuj-id>/<run>`;
   await fs.mkdir(dir, { recursive: true });
   await fs.writeFile(`${dir}/00-initial.png`, await tab.screenshot({ fullPage: false }));
   const snap0 = await tab.playwright.domSnapshot();
   console.log(snap0.slice(0, 2000));  // peek; do not dump the whole thing
   ```

4. **Walk each Journey Step** from the CUJ spec, in order:
   - Build the most stable locator from the latest snapshot: prefer `getByTestId(...)` → stable `data-*` via `locator(...)` → `getByRole(..., { name })` with a plain string name → `getByText(...)` scoped to a container.
   - **Confirm uniqueness with `await locator.count()` before acting** if uniqueness isn't obvious. Proceed only when count is exactly 1.
   - Execute the action:
     ```js
     await tab.playwright.getByRole("button", { name: "Save" }).click();
     await tab.playwright.getByLabel("URL").fill("https://example.com");
     await tab.playwright.getByRole("listbox").selectOption("foo");
     ```
   - Wait for the response with a targeted check:
     ```js
     await tab.playwright.getByText("Saved").waitFor({ state: "visible", timeoutMs: 5000 });
     ```
     Or `tab.playwright.waitForLoadState(...)` for navigation. Do NOT use `tab.playwright.waitForTimeout(...)` — it's disabled in this runtime.
   - Screenshot the new state:
     ```js
     await fs.writeFile(`${dir}/<NN>-<step-slug>.png`, await tab.screenshot({ fullPage: false }));
     ```
   - Verify the "System response" and "User sees" descriptions against a fresh `await tab.playwright.domSnapshot()` — not against source-code assumptions.

5. **Walk each Edge Case & Error State** the same way, with screenshots saved as `${dir}/edge-<N>-<slug>.png`.

6. **Capture console output** after the walk completes:
   ```js
   const logs = await tab.dev.logs({ levels: ["error", "warn"], limit: 200 });
   await fs.writeFile(`${dir}/console.json`, JSON.stringify(logs, null, 2));
   ```
   Any `error`-level entry is a finding — include the full message in the report.

7. **Network verification**: Codex's bundled browser API does not expose a network-requests panel directly. Instead, capture the dev server's stdout via `run_command` (tail the output stream) and verify the expected endpoints were hit. If the CUJ specifies network behavior that cannot be verified server-side (e.g., third-party API call), note the limitation in the report rather than skipping verification.

8. **Close cleanly between runs**:
   ```js
   await tab.close();
   ```

**Visual fidelity comparison against mocks (per Journey Step, both runs):**

Mocks live under `docs/ux/<prd-dir>/cuj-<id>-<state>.<ext>` (PM may follow a slightly different folder layout — discover by globbing `docs/ux/**/cuj-<id>-*.{html,png,jpg,webp,md}`).

1. For each CUJ, use `list_dir` / `grep_search` to find files matching `docs/ux/**/cuj-<id>-*.{html,png,jpg,webp,md}`.
2. If zero matches → log `Mocks: NO_MOCK` for this CUJ in the report. Skip fidelity comparison; continue functional verification only. (Result is unaffected; this is a label, not a failure.)
3. If matches exist, dispatch by extension:
   - **`.html`** — open the mock in a second tab and screenshot it side-by-side with the implementation:
     ```js
     const mockTab = await browser.tabs.new();
     await mockTab.goto(`file://<absolute mock path>`);
     await mockTab.playwright.waitForLoadState({ state: "load", timeoutMs: 5000 });
     await fs.writeFile(`${dir}/<NN>-step-mock.png`, await mockTab.screenshot({ fullPage: false }));
     await mockTab.close();
     ```
     The implementation screenshot already exists from the Journey Step walk (rename it to `${dir}/<NN>-step-live.png` for clarity). Compare both images using your vision capability — check layout, spacing, colors, copy, element presence, hierarchy.
   - **`.png` / `.jpg` / `.webp`** — read the mock image directly (`view_file`) and compare against the Journey Step screenshot using the same visual checks.
   - **`.md`** — read the markdown file. Treat each statement as additional textual acceptance criteria; verify each against the latest `tab.playwright.domSnapshot()` and observed behavior.
4. Any deviation between implementation and mock is logged as a finding with kind `VISUAL_DEVIATION` and a severity that reflects impact:
   - `[LOW][VISUAL_DEVIATION]` — minor cosmetic gap (2px misalignment, slightly different shade, swapped icon).
   - `[MEDIUM][VISUAL_DEVIATION]` — noticeable layout difference, wrong typography, missing decorative element.
   - `[HIGH][VISUAL_DEVIATION]` — primary action button absent or in wrong place, navigation structure wrong, content hierarchy reversed.
   - `[CRITICAL][VISUAL_DEVIATION]` — entire screen layout wrong, page renders unusable, copy completely different from mock.
5. Visual deviations are treated as bugs identical to any other — they roll up into the overall verdict the same way, and dev-cycle Phase 4 applies its loop rules to them by severity (LOW only advances; MEDIUM+ retries).

**Flakiness handling — comparing the two runs:**

- For each Journey Step and Edge Case, compare the per-step outcome between `run1` and `run2`.
- **Both PASS** → step Result is `PASS`. No finding.
- **Both FAIL** → step Result is `FAIL`. Log a bug with kind `BUG` (or `REGRESSION`/`FABRICATION` if it fits the archetypes).
- **One PASS, one FAIL** → step Result is `FAIL` (be pessimistic — the step is unreliable). Log a bug with kind `FLAKY`, severity based on impact. Include both screenshots so the inconsistency is visible.
- The CUJ-level Result rolls up from its steps: any step `FAIL` → CUJ `FAIL`; otherwise `PASS`.

**Per-CUJ requirements that gate the Result:**
- Both `run1` and `run2` artifact dirs exist with at least one screenshot per Journey Step. Missing artifacts for any step → that step Result is `NOT_RUN`, CUJ Result is `FAIL`.
- Console-log capture from `tab.dev.logs()` per run (even if empty); error-level entries logged as findings.
- Every "User sees" assertion verified against `tab.playwright.domSnapshot()` output or screenshot inspection — not against your reading of the source code.
