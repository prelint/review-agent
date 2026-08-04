# Stage 3: The gate

Three filters in series. None substitutes for another.

Filter 1 kills findings that are not real. Filter 2 kills findings that are real and
not worth the author's time. Filter 3 downgrades findings that are real, worth
raising, and unlikely to fire — it never drops. No one of them does another's job.

---

## First: an object with a `kind` is not a finding

Split on the **presence** of that field, never on a list of its values. Anything carrying
a `kind` reports coverage rather than a defect: pass it through untouched, never to a
scorer, never into the ledger's `findings` array. `specialists/_schema.md` owns the list,
and an enumeration here would drift from it — it already had, omitting `end`, which every
findings response now carries.

**A `kind` that is not one of `_schema.md`'s is a dead lens, not a pass-through.** Stage 2
should have caught it; if one reaches here, name that lens as dead and say so, because
passing it through silently is how an object that was meant to be a finding disappears
behind a stray field.

Every lens that finds nothing now emits one, so a run can hand this stage eighteen of
them. Sent to Filter 1 they have no `file:line` to quote; sent to Filter 2 an unparseable
score counts as 100 by the rule below and they survive, land in `findings` at `open`, and
red a clean head.

## Filter 1 — quote or drop

A finding ships only if it quotes the verbatim `file:line` that motivates it.

| Claim | What must be quoted |
|---|---|
| "Field X doesn't exist on model Y" | Y's class body, or its `Meta`, or the migration that would create X |
| "`d.get()` may return None" | the initialisation of `d` |
| "Race between A and B" | both A and B |
| "This endpoint is unauthenticated" | the route decorator and the dependency list |
| "N+1 query" | the loop and the query inside it |

**If you cannot quote it, drop it.** Do not route around this by asserting high
confidence — that is the exact failure the filter exists to catch.

### Framework-generated symbols

When the symbol comes from a metaclass, descriptor, ORM `Meta`, decorator or
migration — Django `Meta`, Rails `has_many`, SQLAlchemy `relationship`, TypeORM
decorators, Prisma's generated client — quote the construct that creates it, not the
class body. The bar is "I read the source that creates this symbol", not "I grepped
for the name and it wasn't there".

This one rule kills the largest false-positive class in the record: confident claims
that a field, method or column does not exist, made by an agent that grepped a class
body and stopped.

---

## Filter 2 — independent scoring

**The agent that found the issue does not score it.** Dispatch a separate scoring
subagent per finding. Give it the finding, the diff, the quoted evidence, and the
rubric below **verbatim**. The finder is invested in its own finding; the scorer is
not, and that is the entire mechanism.

### Rubric — pass this text unchanged

> Score this finding 0–100 for how confident you are that it is a real issue worth
> raising on this pull request. **Any integer is legal — the bands below are anchors,
> not the only allowed answers.** Interpolate: a finding stronger than the 75 anchor
> but short of certainty is an 85.
>
> - **0** — Not confident at all. A false positive that does not survive light
>   scrutiny, or a pre-existing issue not introduced by this change.
> - **25** — Somewhat confident. Might be real, might not. You could not verify it.
>   If stylistic, it is not called out in any project convention file.
> - **50** — Moderately confident. Verified as real, but it may be a nitpick or rare
>   in practice. Relative to the rest of this change, not important.
> - **75** — Highly confident. Double-checked and verified; very likely to be hit in
>   practice. The current approach is insufficient. Directly affects functionality,
>   or is explicitly required by a project convention file.
> - **100** — Certain. Double-checked and confirmed as definitely real, frequent in
>   practice, with evidence that directly demonstrates it.
>
> If the finding cites a project convention, verify the convention file actually says
> that. Do not take the finder's word for it.
>
> You have not been told any previous score for this finding, and must not ask for
> one. Score it from the evidence alone.
>
> Return only: `{"score": N, "why": "<one sentence>"}`

### Threshold

**Below 70 dies.** No exceptions, no "but it's cheap to mention".

**70, because the scale tops out near 88.** Across 38 scored findings the highest score
any scorer returned was 88; no finding reached 90, and none reached the rubric's 100
anchor. An 80 gate against an 88 ceiling passes only the top tenth of the range the
scorer actually uses, which is a far narrower bar than "80 out of 100" reads as. The old
threshold also sat two full steps above the floor `calibration.md` sets for its own
movement rules, on no evidence. Raising it again is one calibration step and needs the
hand sample in `calibration.md`, not a judgement call mid-review.

**The threshold follows the `category` field, never the lens that emitted it.** A lens
may emit on another's behalf — `security` emits the production-reachable test key as
`category: "money"` when `money` is not dispatched — and once per-category thresholds
exist, that finding is scored against `money`'s number. The category is the claim about
what kind of defect this is; the emitter is an implementation detail of who noticed it.
Scoring by emitter would give one defect two different bars depending on which lens saw
it first, which is the whole reason the handoff stamps a category at all.

**The rubric must stay continuous for that number to mean anything.** A five-value
rubric — 0/25/50/75/100 — admits only 100 under any threshold above 75, silently killing
every "highly confident, verified, directly affects functionality" finding at 75. The
threshold this was inherited at, 80, sat just above that band.
That is a live bug in the plugin this rubric came from
([claude-plugins-official #1852](https://github.com/anthropics/claude-plugins-official/issues/1852))
and it was inherited here verbatim. If you ever tighten the rubric back to fixed
bands, move the threshold onto a band.

**An unparseable or missing score counts as 100, not 0.** Fail toward keeping the
finding. A scorer that errors out must not silently suppress what it was asked to
judge.

**Watch for a dead scorer.** The failure mode is silent: a scorer that errors on every
call returns unparseable output, every finding counts as 100, and the review looks
unusually decisive. Three signatures, all cheap to check before posting — every finding
in a review scoring exactly 100, no finding ever landing between 70 and 88, or the gate
killing nothing at all across a whole run. Say so in the summary when you see any of
them. A gate that has stopped filtering reads exactly like a gate that found nothing to
filter.

**None of the three catches a scorer that is wrong but plausible.** A misconfigured
prompt returning 88, 91, 95 for everything passes all of them and suppresses exactly
nothing while looking healthy. No signature computed from the scores alone can — the
numbers are the thing under suspicion. The only check that reaches it is reading the
findings against their scores, which is `calibration.md`'s hand sample and is the
reason that sample is not optional there. Until one has been taken, a scoring run is
evidence that the scorer answered, never evidence that it judged.

**The scorer is blind to any earlier score.** Shown a previous number, a second pass
anchors to it and stops being independent, which is the whole mechanism.

Per-category thresholds are the plan, not the present. Today every category uses 70.

The mechanism — what signal, where it is stored, and why it cannot live in the agent —
is in `calibration.md`, along with an honest note that none of it is implemented. Do
not act on a per-category threshold until `review-agent.thresholds.json` exists.

---

## Then: exclusions

Apply `exclusions.md` as a blocklist. A finding matching any listed pattern drops
regardless of score. Order matters — a 95-scored "outdated dependency" finding still
dies here.

---

## Dedupe

Findings carry a `fingerprint` of `path:anchor:category` — a greppable symbol, never a
bare line number, because the key has to survive code moving above it. See
`specialists/_schema.md`.

- Same fingerprint from two specialists → keep the one with better evidence, record
  both categories on it.
- Same `path:line`, different category → keep both only if they propose different
  fixes. If the fix is the same, they are one finding.
- Same finding as a reviewer's existing comment in the ledger → **do not post it
  again.** Link the ledger item and handle it there. Restating a bot's finding back
  at it was a real source of noise.
- Same fingerprint as a finding **we** posted on an earlier run → do not post it again.
  `intake.md`'s previous-run load puts it in the ledger with the status its marker
  carries; carry that forward. A fleet reviewing the same PR every hour otherwise
  re-posts the same nit every hour.
  **A `BLOCKER` is never suppressed this way.** Post it again and reconcile it again: a
  blocker that was posted and not fixed is still blocking, and the marker it matched is a
  public comment anyone can write. Silencing a blocker on a fingerprint match would let a
  PR author retire review of their own code by pasting one line.

Every suppression above is a real ending, so record it: the finding is `dropped`, with
the ledger item or the fingerprint it merged into. A suppressed finding with no status
sits `open` forever and reds a clean head.

---

## Filter 3 — likelihood, which downgrades but never drops

Score answers "is this claim true". Severity answers "how bad if it fires". Neither
answers **"will it fire at all"**, and one number cannot carry both — a finding can be
95% certainly-true and 5% will-ever-happen at the same time.

That gap is the dominant failure mode of LLM reviewers. They produce an endless supply
of correct findings whose triggering conditions cannot occur here, and the author pays
to read and dismiss each one.

Each finding arrives from Stage 2 with a `likelihood` band and a named `condition`
(see `specialists/_schema.md`). Apply:

| Band | Effect |
|---|---|
| `likely` | No change |
| `plausible` | No change. `BLOCKER` requires at least this. |
| `remote` | Downgrade one step — `BLOCKER`→`REQUIRED`, `REQUIRED`→`NIT`. Keep the condition in the text. |
| `unverified` | No downgrade. Label it `unverified` in the output and say what you would need to check it. |

Two rules that matter more than the table:

**Downgrade, never drop.** The author may know the condition is reachable for reasons
the diff does not show. Downgrading hands them the call; deleting takes it away, and a
filter they cannot see reads as "the reviewer found nothing". Under the output caps in
`output.md`, remote findings will usually surface as a count rather than in full —
that is the intended cost, not a silent drop.

**`unverified` is not `remote`.** If a specialist could not check the condition, that
is a gap in the review, not evidence the finding is harmless. Guessing low and
guessing high are the same error.

A finding downgraded with no stated condition is a review bug. Send it back.

---

## Severity

Assign after scoring, never before. Score is "is this real"; severity is "how much
does it matter"; likelihood is "will it fire". All three are independent, and
conflating any two inflates both.

| Prefix | Meaning |
|---|---|
| `Blocker:` | Breaks behaviour, leaks data, loses money, or blocks rollback — **and** `likelihood` is `plausible` or better. Merging is wrong. |
| `Required:` | A real defect that should be fixed in this PR. |
| `Nit:` | Minor. The author may decline it without justifying the decision. |
| `FYI:` | No action wanted. Context only. |

Reserve `Blocker:` for the four named consequences. Everything else is `Required:` at
most. An unlabelled finding reads as mandatory, which is how a review of eleven nits
becomes a day of someone's work.
