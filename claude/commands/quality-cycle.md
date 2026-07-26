---
description: Run the autonomous quality-improvement loop for one quality surface (quality-cycle <slug>). Orchestrates evaluator (measure), researcher (diagnose + design experiment), coder (implement in worktree), evaluator (score + gate) — iterating within the qspec's eval budget until thresholds are met on holdout, a plateau needs the user's decision, or a blocker surfaces. Requires a calibrated instrument from /design-quality.
---

# quality-cycle — One autonomous quality-improvement session

You are the orchestrator of hypothesis-driven quality improvement. Where `/dev-cycle` builds *capability* against deterministic acceptance criteria, this loop climbs a *distribution* toward the qspec's thresholds. The inner rhythm: measure → diagnose → experiment → measure → gate — with the separation of powers intact at every step: evaluator owns numbers, researcher owns hypotheses, coder owns implementation, and nobody grades their own work.

## Setup

1. **Target**: `quality-cycle <slug>` → all artifacts under `docs/quality/<slug>/`. No slug and exactly one directory under `docs/quality/` → use it; multiple → ask which (interactive) or BLOCKER (invoked headless).
2. Read `qspec.md`, `eval-report.md` (if any), `experiments.md` (if any), `ledger.md`, and `quality-loop-state.md` (if any). No qspec → stop: "run `/design-quality` first."
3. **Autonomous preamble + worktree label**: this skill inherits both mechanisms from `/dev-cycle`'s Setup section (read them from `dev-cycle.md`, deployed alongside this file) — prepend the preamble to every subagent prompt; prefix every `description` with the worktree label. Any subagent `BLOCKER:` return → write `quality-loop-state.md` with status `blocked` + the text, stop, notify the user.
4. **Budget**: the qspec's per-cycle eval budget minus `ledger.md` entries for this cycle. Zero remaining → report and stop; the user decides whether to fund another cycle.

## Phase Q0: Instrument check

Spawn `evaluator`: verify the judge is calibrated against the *current* qspec (recalibrate if the qspec changed since `judge/calibration-record.md`), the eval set exists with a dev/holdout split, and the noise floor is recorded. Any failure → status `blocked` with the evaluator's reason (a calibration failure routes back to `/design-quality`, not around it). **No measurement, no loop** — proceeding past a broken instrument is how autonomous improvement becomes autonomous self-deception.

## Phase Q1: Baseline

If no baseline report exists for current `main` (or quality-surface files changed since the last one — check git log against the report's run metadata), spawn `evaluator` for an official **baseline** run on the dev set. Otherwise reuse the standing baseline; don't spend budget re-measuring an unchanged pipeline.

If the baseline already meets every dev-set threshold → skip to Phase Q5's holdout confirmation.

## Phase Q2: Diagnosis + experiment design

Spawn `researcher`: full state read, diagnose the top failure category, return either
- **an experiment spec** (one mechanism, prediction stated, probe authorization if applicable), plus any measurement disputes / eval-set gap proposals, or
- **a plateau candidacy** with evidence ("remaining hypotheses are low-plausibility/high-cost because...").

Route side-channels before proceeding: a measurement dispute goes to `evaluator` (instrument investigation — if it recalibrates or corrects anything, the affected runs re-score before any gate decision); eval-set gap proposals go to `evaluator` to accept/decline; rubric ambiguities are logged for the exit report (they're pm + user territory).

## Phase Q3: Implement the experiment

Spawn a `coder` (`isolation: "worktree"`, background): the researcher's spec verbatim — it's already in coder's native format. Branch label: `exp/<EXP-id>`. The spec's "Done when" ends at building + smoke subset; the coder does **not** run official scoring.

Record the experiment as `running` in the notebook (spawn `researcher` briefly, or fold into Q5's entry — never write `experiments.md` yourself; the orchestrator writes only `quality-loop-state.md`).

## Phase Q4: Score + gate

1. Spawn `evaluator`: official **experiment** run against the coder's branch; report with delta vs baseline and the mechanical **gate verdict** (ACCEPTED / REJECTED, naming the deciding qspec rule).
2. **Eval-asset guard** (the Phase 3.5 PRD-guard analog — mechanical, not advisory): before any merge, `git diff --name-only main...<branch> -- docs/quality/ docs/prd/` must be empty. Anything listed → strip it (`git checkout main -- <paths>` on the branch, commit the strip), log the violation + experiment id in `quality-loop-state.md`. An experiment that edited the exam is measured only after the exam is restored.
3. **ACCEPTED** → merge the branch (`--no-ff`). If the winning change is probe-grade (per its authorization line), do not merge; instead file an ENG entry via the eng-backlog convention — "harden EXP-<id> mechanism for production; Verify: smoke eval reproduces the gain" — and route architecture-level graduations through tl in the next `/dev-cycle`. Probe code never lands on main.
4. **REJECTED** → discard the branch (worktree removed, branch deleted). The learning survives in the notebook; the code doesn't.

## Phase Q5: Record + loop control

1. Spawn `researcher`: notebook entry for the completed experiment — result numbers from the report, hypothesis verdict (confirmed / refuted / inconclusive vs its prediction), gate outcome, learning, spawned follow-ups.
2. Update `quality-loop-state.md` (timestamp via the standard one-liner):

```markdown
# Quality Loop State: <slug>
Last updated: <ts>
Iteration: <n> | Status: continue | thresholds-met | plateau | blocked | budget-exhausted
Budget: <used>/<total> official runs
## This cycle
- EXP-<id>: <hypothesis one-liner> — <confirmed/refuted/inconclusive> / <ACCEPTED/REJECTED>
## Plateau counter: <m> consecutive experiments without an accepted improvement
## Blocker (if blocked)
## Next focus
```

3. **Decide**:
- **Budget remaining and no verdict** → next iteration (Q2). One experiment per iteration — deltas must stay attributable.
- **Dev thresholds met** → spawn `evaluator` for the **holdout gate run**. Pass → status `thresholds-met`. Fail → holdout-vs-dev gap goes to the researcher next iteration (usually an overfit or coverage signal — evaluator may propose set refresh).
- **Plateau**: `k` consecutive iterations (qspec's patience) without an accepted improvement, or the researcher's plateau candidacy → status `plateau`. This is a *decision point, not a failure*: stop and present the user a menu with evidence — accept the current level (pm may then record the achieved bar as the qspec's threshold via the user + spec-sync), relax specific thresholds, invest in data/eval coverage, change approach at the architecture level (route to tl), or fund another cycle.
- **Budget exhausted** → status `budget-exhausted`, summary of spend vs progress.

## Exit report (every ending)

```
Quality cycle <n> for <slug>: <status>

Baseline → now: <dimension deltas, hard-fail rate movement>
Experiments: <run> run, <a> accepted, <r> rejected, <i> inconclusive
Budget: <used>/<total> | Plateau counter: <m>/<k>
Notebook: docs/quality/<slug>/experiments.md (entries EXP-<x>..EXP-<y>)

Spot-check (your 2 minutes — this keeps the judge honest):
<the eval-report's k sampled outputs + scores; ask the user to flag any
score they disagree with — a disagreement is a calibration incident and
freezes that dimension's verdicts until recalibration>

Next: <the status-appropriate single next action>
```

The spot-check ask is not decoration — it is the standing human anchor that keeps an autonomous improver aimed at *your* bar rather than the judge's drift. Include it every time; never mark it done on the user's behalf.

## What NOT to do

- Don't run without a calibrated instrument, and don't "provisionally" score past a failed Q0.
- Don't let any experiment branch touch `docs/quality/**` or `docs/prd/**` — the guard strips it mechanically.
- Don't merge probe-authorized code — it graduates through the eng-backlog + tl, or it dies with the branch.
- Don't run experiments in parallel — one mechanism per iteration keeps deltas attributable; parallelize *diagnosis*, never *measurement*.
- Don't spend the last budget entries re-measuring unchanged code, and don't let smoke runs stand in for official ones at any gate.
- Don't treat plateau as failure or push through it — it's the loop correctly returning a product tradeoff to the human who owns it.
- Don't write `experiments.md` (researcher's), `eval-report.md` / sets / judge (evaluator's), or `qspec.md` (pm's + spec-sync's) from the orchestrator — your only file is `quality-loop-state.md`.
