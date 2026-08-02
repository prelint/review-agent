# Calibration

**Status: not implemented.** This file describes the mechanism. Nothing in Stages 1–5
reads or writes a threshold today; `verification.md` uses a flat 80 for every
category. Written down because an earlier draft claimed a feedback loop existed and it
did not.

## The problem this has to solve

The agent has no memory. Every run starts cold, and the ledger is gitignored run state
that dies with the run. So the loop cannot live in the agent — it has to live somewhere
that survives, is shared across machines, and is inspectable.

Two places qualify: **the repo** and **GitHub**. Neither is the agent.

## Reactions are not the signal

An earlier draft attached 👍/👎 to every finding and made reaction counts the input to
per-category thresholds. That is removed.

The reviewers and PR authors in this workflow are mostly agents, and **agents do not
click reactions**. The loop would have collected nothing while adding two dead buttons
to every finding. Even with human reviewers it was ambiguous — 👍 on GitHub reads as
"I agree", not "this finding was accurate" — but the ambiguity was never the binding
problem. The absence of clickers was.

Anthropic's managed Code Review does run this loop, and it works for them because the
signal is aggregated across many human-operated repos and consumed on their servers.
It does not transfer to a fleet.

## Outcome is the signal

Every finding's real outcome is already recorded by Stages 4 and 5, in durable places,
with no convention anyone has to understand:

| Outcome | Recoverable from | Means |
|---|---|---|
| A commit cites the fingerprint | `git log --grep` on the merged PR | Useful |
| Rebutted with evidence | the thread reply, the ledger resolution | Not useful |
| Deferred to an issue | the resolution + the issue link | Useful, wrong time |
| Thread resolved, no citing commit | GitHub thread state | Weak useful |
| Still open at merge | absence of the above | Unknown |

This works *better* with agent authors than with human ones. Stage 4 writes
`Finding: <specialist>/<fingerprint>` into every commit message mechanically, and an
agent driving the PR through this same skill cannot leave a ledger item open — Stage 5
will not let it. Humans forget to cite and leave threads dangling; the unknown bucket
is small here and large everywhere else.

### The hazard, and it is real

Agents comply. An agent author will fix almost anything it is told to fix, so "a
commit cites the fingerprint" measures *what was raised*, not *what was worth raising*.
Left alone, every category converges on 100% useful and no threshold ever moves.

Two counters, both cheap:

- **Weight the rebuttal.** Rebutting costs evidence — the downstream agent has to
  quote code proving the finding wrong. A rebuttal is therefore a much stronger
  negative signal than a fix is a positive one. Score `useful_rate` as
  `1 - (rebutted / resolved)`, not `fixed / resolved`.
- **Sample by hand.** Every calibration run, print 10 random `fixed` findings for a
  human to skim. If a category's fixes read as busywork, the rate is lying and the
  threshold goes up regardless of the number.

Until someone has looked at a sample, treat every rate as provisional.

## Making findings findable later

A finding posted today must be identifiable months later by a process that was not
running when it was posted. One invisible marker does it:

```html
<!-- review-agent: category=tenancy fingerprint=backend/apps/billing/services.py:142:tenancy score=88 -->
```

HTML comments do not render on GitHub. Without this, category is unrecoverable from a
posted comment and per-category rates cannot be computed at all. This ships first or
nothing else works.

## The calibrate pass

Separate command, run on a cadence. **Never part of a review run** — a run must not
change the rules it is judged by, and a per-run loop would tune on one sample.

1. List merged PRs since the last calibration.
2. Collect our findings from them by their HTML markers.
3. Resolve each to an outcome from the table above.
4. Per category: `useful_rate = 1 - (rebutted / resolved)`. Report the unknown bucket's
   size alongside it; a large unknown bucket means the number is not trustworthy.
5. Print 10 random `fixed` findings for the human sample.
6. Require 20 resolved findings in a category before moving anything.

## Thresholds live in the repo

```json
{
  "_comment": "Written by `calibrate`. Read by Stage 3. Commit this.",
  "default": 80,
  "categories": {
    "tenancy":    {"threshold": 75, "useful_rate": 0.92, "n": 24, "sampled": "2026-08-02"},
    "spec-drift": {"threshold": 90, "useful_rate": 0.38, "n": 39, "sampled": "2026-08-02"}
  }
}
```

`review-agent.thresholds.json`, repo root, **committed**. That is the whole answer to
"how does a stateless agent remember": it does not — the repo does, the change is
reviewable in a diff, and every machine and every agent reads the same file.

Movement rules, deliberately asymmetric:

- `useful_rate < 0.40` → threshold up by 10, capped at 95.
- `useful_rate > 0.60` → threshold down by 5, floored at 70, **and only if a human
  sample has been taken since the last move.** Loosening on an unsampled rate is how
  agent compliance quietly turns into noise.
- Between → no change.
- Three consecutive calibrations at 95 below 0.40 → recommend dropping the specialist.
  Recommend, never do: removing a lens is a human decision.

Never move more than one step per calibration, never on fewer than 20 resolved
findings.

### Where 40/60 come from

Industry write-ups on AI review adoption. Not a controlled study, not measured here,
and not measured on agent-authored PRs at all. The shape is right — trust erodes
faster from noise than from a miss — but the numbers are placeholders to be replaced
by our own outcomes. Tunable, not evidence.

## Numbers with no source

Every threshold in this repo that was chosen rather than measured. Each is a candidate
for the first real calibration pass, and each is written here so nobody mistakes it for
evidence.

| Number | Where | Basis |
|---|---|---|
| 1 missing-test finding reported in full | `specialists/testing.md` | None. Chosen to stop coverage sweeps. Raised twice in review as arbitrary — a diff with three untested branches has three gaps. Now overflows to a count rather than dropping, so the cap bounds volume without losing information. Whether the right number is 1 or 2 is answerable from the logs. |
| 80 score threshold | `reference/verification.md` | None. Conservative in the direction trust erodes. |
| 40 / 60 useful-rate bands | this file | Industry write-ups, not measured here, not measured on agent-authored PRs. |
| 2,000 character summary cap | `reference/output.md` | Measured — the old median posted comment was 1,718 and the worst was 10,289. The only number here with a source. |
| 5 non-blocking findings | `reference/output.md` | None. |
| 400 words per lens | `specialists/_schema.md` | None. |

## Order of work

1. HTML markers on posted findings. Nothing else works without it.
2. `review-agent.thresholds.json`, read by Stage 3, hand-edited at first.
3. The `calibrate` pass, with the human sample built in from the start.

Until (1) ships, no calibration claim belongs in any other file in this repo.
