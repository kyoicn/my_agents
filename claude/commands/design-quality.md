---
description: Design a quality bar for a quality-bearing feature (summarization, ranking, extraction, data pipelines...). Drives a conversational calibration session — your judgments on real candidate outputs become an anchored rubric — then detects the measurement shape, runs a labeling session, has pm write the qspec, and has evaluator build + calibrate the judge and seed the eval set. Ends with a working, validated measurement instrument or an honest BLOCKED.
---

# design-quality — Calibrate a quality bar into a measurable spec

You are the orchestrator of a quality-bar design session. The product is not prose — it's a **working measurement system**: a qspec whose anchors came from the user's actual judgments, a judge that provably agrees with the user, and a seeded eval set. `/quality-cycle` can only climb toward a bar this session makes real.

The governing principle: **the bar lives in the user's reactions to concrete examples, not in adjectives.** "Accurate and concise" is not a spec; the user saying *"B is better than A because A invented a number, and C is technically right but twice too long"* is a spec — this session's job is to extract and operationalize enough of those judgments.

Separation of powers (why this session is structured as it is): pm + user set the bar; evaluator builds the instrument; the improvers (researcher, coder) touch neither. This session involves only the first two.

## Phase 0: Context + measurement-shape detection

1. Read `docs/prd/index.md` and the relevant PRD — a quality surface usually belongs to a CUJ ("CUJ-4: generate article summary"). Identify the **quality surface**: what inputs, what outputs, where produced in the code (find the pipeline/prompt files). If the feature isn't built at all, stop: the dev-cycle builds capability first; this session needs real or realistic outputs to calibrate against.

2. Pick the **slug** — all artifacts live under `docs/quality/<slug>/` (e.g. `docs/quality/summary/`).

3. **Detect the measurement shape** and confirm it with the user:

| Shape | Signature | Instrument implication |
|---|---|---|
| **absolute-graded** | Each output judged on its own against scales (summaries, generations) | LLM judge per dimension; per-item eval unit |
| **comparative** | Quality is an ordering (ranking, recommendations) | Pairwise/list judgments; eval unit is query + slate; judge needs position-bias controls |
| **ground-truth** | Correct answers exist (extraction, classification) | Programmatic scoring vs labels; LLM judge only for fuzzy fields |
| **proxy** | Output invisible to users (internal pipeline stages) | Quality defined via a named proxy (downstream effect, intermediate correctness); the qspec must state the proxy's known gaps |

The shape drives everything downstream — say it out loud and get agreement before proceeding. Mixed surfaces (a ranker that also generates snippets) get one qspec per shape-coherent dimension group.

## Phase 1: Calibration conversation — dimensions and anchors from real judgments

Conversational, in the main thread, like `/design-feature` discovery — no `AskUserQuestion`, free-form text. **One dimension at a time, like one mock per turn.**

1. **Assemble 3–5 real inputs** spanning the distribution (for a summarizer: a normal article, a long one, a listicle, one with tables). Prefer real project data; ask the user to point at some if none is at hand.

2. **Produce candidate outputs.** If the pipeline exists, run it; *additionally hand-write 1–2 deliberately different variants per input* (one too terse, one subtly unfaithful, one verbose-but-accurate...). Contrast is what elicits judgments — three similar outputs teach nothing.

3. **Elicit, don't survey.** Show one input + its candidates. Ask which meets the bar and *why the others don't*. Push past adjectives exactly as pm pushes in design discovery: "'not accurate enough' — point at the sentence. Is it wrong, unsupported, or misleading?" The user's vocabulary becomes the **dimension names**; their reasons become the **anchor descriptions**.

4. **Draft each dimension with an anchored scale** (1–5; anchor 1, 3, 5 minimum) where every anchor cites a real example from this session. An anchor without an example is an adjective — not allowed.

5. **Hunt hard constraints explicitly**: "Is there anything that makes an output unacceptable *regardless* of how good it otherwise is?" (fabricated facts, leaked PII, output in the wrong language). These become auto-fail rules, not scale points.

6. **Force the tradeoffs**: "When accuracy and conciseness conflict, which wins?" Rank the dimensions. `/quality-cycle`'s gate needs this ordering to accept or reject mixed-result experiments.

7. **Set thresholds** — propose defaults, let the user adjust: per-dimension mean target, a tail target (e.g. p10 ≥ 3 — "the bad ones can't be terrible"), hard-fail rate ceiling (e.g. < 1%). Also set the **loop parameters** the qspec carries: eval budget per quality-cycle (official runs), plateau patience k (default 3), judge agreement threshold (default: ≥ 85% exact-or-adjacent on a 5-point scale).

## Phase 2: Labeling session — the calibration set

The judge will be trusted only as far as it agrees with the user. That requires labels.

1. Assemble **30–50 input+output pairs** spanning the strata and the quality range (deliberately include bad outputs — a calibration set of only good examples can't catch a lenient judge).
2. The user labels them against the drafted rubric, **in batches of ~10 per turn** — this is tedious; say so, offer to pause and resume across sessions (the batch files persist under `docs/quality/<slug>/calibration/`).
3. Watch for rubric failure while labeling: if the user's labels contradict the anchors ("you scored this 4 but the anchor for 4 says..."), stop labeling and fix the rubric first — label churn against a moving rubric is wasted user time.
4. Store labels as `docs/quality/<slug>/calibration/labels.md` (one block per item: input ref, output, per-dimension scores, hard-fail flags, the user's one-line reason when given).

## Phase 3: pm writes the qspec

Spawn a `pm` subagent. The prompt is fully self-contained (embed everything — pm cannot see this conversation) and begins with the standard declaration:

```
You are invoked non-interactively — the calibration conversation already
happened in the main thread; no user is available to you. Do not ask
questions. If the handoff below is contradictory or incomplete, return
"BLOCKER: <description>" instead of guessing.

Write docs/quality/<slug>/qspec.md from the handoff below, following the
template exactly. The qspec is PURE SPEC — it defines the bar; it never
records scores, progress, or experiment history (those live in
eval-report.md and experiments.md). You own this file the way you own
PRDs: sole writer, spec-sync's minimal user-confirmed amendments are the
only exception.

## Handoff
[Embed: slug, quality surface + owning CUJ/PRD refs, measurement shape,
every dimension with its full anchored scale and example citations, hard
constraints, tradeoff ranking, thresholds, strata list, loop parameters
(budget, plateau k, agreement threshold), calibration-set path.]

## qspec template (follow exactly)

# Quality Spec: <feature name>

> Owned by pm. Pure spec — never a progress tracker.
> Serves: CUJ-<id> (prd-NNN-<slug>)

## Surface
What is being judged: inputs, outputs, where produced (file refs).
**Measurement shape**: absolute-graded | comparative | ground-truth | proxy
(For proxy: the proxy definition and its known gaps.)

## Dimensions
### <dimension> (rank N in tradeoff order)
Definition: one sentence.
Scale:
- 5: <description> — e.g. <real example ref>
- 3: <description> — e.g. <real example ref>
- 1: <description> — e.g. <real example ref>

## Hard constraints (auto-fail regardless of scores)
- HC1: <rule> — e.g. <real example ref>

## Thresholds (the bar)
| Dimension | Mean ≥ | p10 ≥ |
|---|---|---|
Hard-fail rate ≤ <x>%. All measured on the holdout at gate time.

## Tradeoff priorities
<ordered list + one sentence on how the gate uses it>

## Strata
<input categories the eval set must cover, from the calibration session>

## Loop parameters
Eval budget per quality-cycle: <N official runs>. Plateau patience: <k>.
Judge agreement threshold: <x>% exact-or-adjacent vs calibration labels.

Return: created file path + any BLOCKER.
```

## Phase 4: evaluator builds the instrument

Spawn an `evaluator` subagent (autonomous preamble applies): prompt it to execute its Instrument Build process for `<slug>` — write judge assets, **calibrate against `calibration/labels.md`**, seed the eval set (dev/holdout split across the qspec's strata), install `scripts/eval-runner.sh`, and establish the noise floor.

Three possible returns, all honest:
- **Calibrated** (agreement ≥ threshold): report the agreement number and per-dimension breakdown. Done.
- **Calibration failed**: the judge can't reproduce the user's judgments. This usually means the *rubric* is ambiguous, not the judge — return to Phase 1 with the evaluator's disagreement examples ("judge and you disagree most on borderline-conciseness items; the anchor for 3 doesn't decide them") and refine. Two failed round-trips → step back with the user: this bar may not be operationalizable as specified. Say so plainly; that exit beats fake numbers.
- **BLOCKER** (missing prerequisites, unusable data): surface and stop.

## Phase 5: Handoff

```
Quality bar calibrated: <slug>

qspec:        docs/quality/<slug>/qspec.md
Judge:        calibrated at <x>% agreement (threshold <y>%)
Eval set:     <n> dev / <m> holdout across <k> strata
Noise floor:  ±<f> on <dimension means>
Budget:       <N> official runs per quality-cycle

Next: run /quality-cycle <slug> to start improving toward the bar.
```

## What NOT to do

- **Don't accept adjectives as anchors.** Every scale point cites a real example from the session, or it doesn't exist yet.
- **Don't skip the deliberately-bad candidates** — contrast elicits judgment; consensus candidates elicit nothing.
- **Don't let the labeling session run against a shifting rubric** — fix the rubric first, then label.
- **Don't write the qspec yourself** — pm's subagent owns the file write, same as design-feature Phase 1.
- **Don't proceed past a failed calibration by lowering the agreement threshold** — that's fabricating the instrument. Refine the rubric or stop honestly.
- **Don't design improvement experiments here** — that's researcher territory inside `/quality-cycle`. This session defines the bar and the instrument, nothing else.
- **Don't create quality specs for deterministic behavior** — "the export button downloads a CSV" is a PRD acceptance criterion for the dev-cycle, not a quality dimension.
