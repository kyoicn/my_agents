---
description: Adversarial exploratory testing — kick off a gorilla session against the running product. Manual invocation only; you decide when the product is stable enough. Default 30-min time budget, configurable. Optional URL path filter. Files every finding as an h3 block to docs/issues.md regardless of severity; writes session summary to docs/gorilla-report.md.
---

# gorilla-test — Adversarial exploratory testing

You are the orchestrator for a gorilla testing session. The gorilla agent does the actual attacking; your job is to set up the session, kick the gorilla off with the **minimal** context it needs (product summary + URL + budget + optional path), and handle the handoff back to the user when the session ends.

This skill is **manual-only**. It is intentionally not part of `/dev-cycle`. The user decides when the product is stable enough for gorilla testing to find signal worth fixing — typically not for a brand-new product on day 3, but for one approaching real users on day 30.

## Phase 0: Parse args

Args may include `--time <duration>` and `--path <path>`. Examples:

- `/gorilla-test` → 30-min budget, whole product
- `/gorilla-test --time 45m` → 45-min budget
- `/gorilla-test --path /articles` → 30-min budget, focused on `/articles`
- `/gorilla-test --time 1h --path /articles` → both

Defaults:
- **Time budget: 30 minutes**
- **Path filter: none** (whole running product)

Validation:
- Time budget must be in `<N>m` or `<N>h` form. Reject other shapes with a usage hint.
- Time budget must be ≤ 4 hours (`240m` / `4h`). A runaway session is worse than a short one.
- Path filter must start with `/`. Reject malformed paths.

If args are valid but unusual (e.g., `--time 5m` — too short to be useful), surface a one-line warning but proceed.

## Phase 1: Generate session ID

```bash
echo "gorilla-$(date '+%Y-%m-%d-%H-%M-%S')"
```

The result (e.g., `gorilla-2026-06-05-14-30-22`) is the session ID — used for the artifact directory name and the session reference embedded in every issue block.

## Phase 2: Ensure dev server is running

```bash
./scripts/qa-server.sh status
```

- **Exit 0** → server is running. Capture the base URL from the script's output (typically `http://localhost:<port>/`).
- **Exit non-zero** → run `./scripts/qa-server.sh start`. After start, re-run `status` to confirm and capture the URL. If start fails (script missing, port conflict, dev command broken), surface the error from the script's output to the user and stop. Do not proceed with attacks against a non-running product.

If `scripts/qa-server.sh` doesn't exist (the project has never run QA), tell the user:

> `scripts/qa-server.sh` is missing — the gorilla relies on QA's canonical dev-server lifecycle script. Run `/dev-cycle` once first (which bootstraps the script via the QA phase), or create `scripts/qa-server.sh` by hand using the template in `agents/qa.md` Step 1a.

Then stop. Don't try to invent a replacement.

## Phase 3: Extract product summary

The gorilla needs a one-paragraph product description so it knows what kind of product it's attacking — but **not** the spec. Read `docs/prd/index.md` and extract the product vision (typically 1-2 sentences from the top-level vision/overview section).

- If the vision section is short (≤ 3 sentences), quote it verbatim.
- If longer, condense to 1-2 sentences in your own words.
- If `docs/prd/index.md` doesn't exist, ask the user for a one-line product description before proceeding. Do not invent context.

You may also peek at `docs/prd/index.md`'s "User personas" section if present, to add a sentence about who the target user is — that helps the gorilla simulate the right kind of attacks (a power-user app gets different bugs than a consumer app).

**Do NOT pass per-CUJ details, mocks, design docs, or implementation files.** The gorilla is black-box on purpose. Resist the urge to "help" the gorilla with extra context — the value of black-box testing is finding what spec-driven testing misses.

## Phase 4: Spawn the gorilla agent

Spawn a `gorilla` subagent with this prompt structure (substitute the bracketed values):

```
You are running a gorilla testing session. Session details:

- Session ID: <session-id>
- Time budget: <budget>
- Product summary: <1-2 sentences from index.md, verbatim or condensed>
- Base URL: <URL from qa-server.sh status>
- Path filter: <path or "none">

Execute the full process from your role definition (Steps 1-6):
1. Session setup — create the artifact dir, ensure .gitignore is correct,
   verify the dev server (via ./scripts/qa-server.sh) and the browser.
2. Walk the attack taxonomy (9 categories) within the time budget.
3. Honor the stop criteria (time exhausted, coverage + diminishing returns,
   or a CRITICAL finding short-circuit).
4. Document each finding with evidence as you go (screenshots, console,
   network, repro steps).
5. End of session:
   - Append one h3 block per finding to docs/issues.md (file every finding
     regardless of severity).
   - Overwrite docs/gorilla-report.md with this session's summary.
6. Final clean-up — optional dev-server stop.

Return: a one-paragraph session summary, the list of issue IDs filed
(with severity tags), and whether you early-stopped (and why).
```

If the gorilla returns a BLOCKED status (Playwright MCP not installed), relay the install instruction to the user and stop. Do not attempt to continue without the browser.

## Phase 5: Hand off to the user

After the gorilla returns, print a single concise summary tailored to the outcome.

### Normal completion

```
Gorilla session <session-id> complete.

Findings filed to docs/issues.md (<total> total):
  - <issue-id> [<severity>] <short title>
  - <issue-id> [<severity>] <short title>
  - ...

Session summary: docs/gorilla-report.md
Artifacts: docs/gorilla-artifacts/<session-id>/

Suggested next step: run /triage to diagnose the new issues, then /quick-fix
or /dev-cycle per the recommended action on each.
```

### Early stop on CRITICAL

Lead with the critical finding:

```
⚠️  CRITICAL finding — session ended early after <Hh Mm>.

  Issue <issue-id>: <title>
  Repro and evidence: docs/issues.md (block <issue-id>)
  Screenshot:        docs/gorilla-artifacts/<session-id>/<NN>-<slug>.png

Recommended: address this before further gorilla testing. The session
report (docs/gorilla-report.md) and any other findings (if the gorilla
captured them before stopping) are also available.
```

### No findings

```
Gorilla session <session-id> complete. No reproducible findings in this run.

Session summary: docs/gorilla-report.md
Coverage: <N> attack categories touched, <total> attacks attempted.
```

Don't editorialize. Don't recommend re-running — the user knows their cadence. Don't auto-trigger `/triage` — give the user a chance to read the report first.

## What NOT to do

- **Don't pass CUJ details, mocks, design docs, or implementation context to the gorilla.** Black-box at attack time is the whole point. Resist the urge to "improve" the prompt by adding hints.
- **Don't run as part of `/dev-cycle`.** Gorilla testing is manual; the user picks the cadence based on product stability.
- **Don't filter findings before the gorilla files them.** Every reproducible finding becomes a `docs/issues.md` block, regardless of severity. `/triage` is where prioritization happens — later, on the user's terms.
- **Don't auto-trigger `/triage` or `/quick-fix` after the gorilla finishes.** Let the user review the report first and decide. (Mention them in the handoff message as suggested next steps, but don't invoke.)
- **Don't manage the dev server directly.** Use `./scripts/qa-server.sh` for status / start / stop. Never `npm run dev`, `kill`, `lsof`, or `tail`.
- **Don't allow time budgets > 4 hours.** A runaway gorilla session burns tokens and produces low-value output past the point of diminishing returns. Reject and ask the user to specify a sane budget.
- **Don't proceed against a non-running product.** If the dev server can't be started, surface the error and stop. Attacking a 404 page is meaningless.
