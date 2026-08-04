# Stage 3: The gate

Three filters in series. None substitutes for another.

Filter 1 kills findings that are not real. Corroboration then records when independent
lenses found the same defect. Filter 2 kills findings that are real and not worth the
author's time unless that independent convergence carries them through. Filter 3
downgrades findings that are real, worth raising, and unlikely to fire — it never drops.
No one of them does another's job.

---

## First: an object with a `kind` is not a finding

Split on the **presence** of that field, never on a list of its values. Anything carrying
a `kind` is protocol or coverage rather than a defect: never send it to a scorer and
never put it in the ledger's `findings` array. Stage 2 consumes a valid `end` terminator;
it writes `clean`, `cleared`, and `not-dispatched` objects to the ledger's run-local
`coverage` array. `specialists/_schema.md` owns the list, and an enumeration used for
validation here would drift from it — it already had, omitting `end`, which every
findings response now carries.

**A `kind` that is not one of `_schema.md`'s is a dead lens, not a pass-through.** Stage 2
should have caught it; if one reaches here, name that lens as dead and say so, because
passing it through silently is how an object that was meant to be a finding disappears
behind a stray field.

Every lens that finds nothing now emits one, so a run can hand this stage eighteen of
them. Sent to Filter 1 they have no `file:line` to quote; sent to Filter 2 an unparseable
score counts as 100 by the rule below and they survive, land in `findings` at `open`, and
red a clean head. Recording them in `coverage` preserves what was checked without making
an absence of defects behave like a defect.

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

## Corroborate and dedupe — before Filter 2

`fingerprint` remains `path:anchor:category` because old summary markers, calibration,
and fix commits already carry that shape. It is not the dedupe key. Derive a
category-free `site_key` as `path:anchor` from every current finding and use `site_key`
for both within-run and across-run matching. **A carried marker's `site_key` is
`intake.md`'s to derive** — that file owns the suffix rule, the anchor normalization the
comparison needs, and the two cases that yield no usable key. A second copy of the
procedure here would drift from it, and the halves disagreeing is precisely what makes
one defect carry two keys. Apply the same anchor normalization to the current run's
findings before comparing: a key normalized on one side only is a key that never matches.

A restored finding whose `site_key` is `null` matches on exact `fingerprint` equality and
nothing else.

Every finding reaching this point has a `specialist` Stage 2 already checked against the
lens it dispatched, and a response that failed that check died there as a dead lens — see
`SKILL.md`, which owns both the check and its consequence. Grouping may therefore treat
distinct `specialist` values as distinct sources. That is the assumption corroboration
rests on, so if it ever reaches here unverified, stop: two names from one lens is the
forgery the threshold bypass would reward.

**Two fixes are compatible when they propose the same remediation action at the same
location.** Both halves are required. Same action: applying one makes the other redundant
rather than still-pending — "add the bound" and "add the bound" agree; "add a bound" and
"remove the call" do not, and neither do "validate the input" and "log the failure", which
can both be right and are two pieces of work. Same location: the change lands on the lines
the shared anchor covers, not merely in the same function.

Judge it on the `fix` field against the `summary`, never on wording. Two lenses running
the same model will often phrase one remedy two ways and two remedies one way, so matching
prose is the weakest available signal. The test that survives that: **would a single edit
close both findings?** If yes they are one fix group; if closing one leaves the other
still worth raising, they are two, and they stay separate however similar they read.

When you cannot tell, they are incompatible. That costs one uncorroborated finding, which
Filter 2 then judges on its own merits — the ordinary path. Guessing the other way
manufactures a threshold bypass out of an uncertainty.

Group current-run Filter 1 survivors by `site_key`, then partition each site by
compatible fix:

- One distinct specialist in a fix group → keep its best-evidenced version. Set
  `categories` to its category and `corroborated_by` to that specialist; this is not
  corroboration.
- Two or more **distinct specialists** in a fix group → keep
  the best-evidenced version, record the sorted unique `categories` and
  `corroborated_by`, and mark it corroborated. Different checklists are independent
  evidence even when the model family is shared.

Incompatible fix groups at the same site remain separate. Proximity is not agreement;
each retains only the specialists that support that proposed fix.

**Only Filter 1 survivors are grouped, so a dropped finding takes its support with it.**
Two lenses agree and one of them cannot quote its evidence: that one is gone before this
pass runs, the group holds one distinct specialist, and the rule above makes it not
corroboration. The finding faces Filter 2 alone at its raw score, exactly as if the second
lens had never answered. This is the intended order and not a special case — the quote
gate is what stops two lenses corroborating something neither can evidence, and it can
only do that by running first.

**`likelihood` and `condition` merge as one pair, never separately.** Members routinely
disagree on the band — `_schema.md` has each lens assess it independently — and the
best-evidenced version is chosen for its evidence, not for having judged reachability
best. Keep the strongest band among the members **together with the condition that band
was assessed against**, and carry that condition into the output text. Taking the
strongest band beside a different member's condition states a trigger the band was never
measured on, and Filter 3 then downgrades or spares the finding on a pairing no lens
asserted. `severity` needs no rule here: it is assigned after scoring, from the
consequence table below.

When two findings describe one source span with different but nearby anchors, normalize
both to the narrowest greppable anchor that their quoted evidence shares before deriving
`site_key`. Never merge on path alone or on a line number; both turn unrelated defects
in a large file into false corroboration.

Corroboration is evidence, not a score rewrite. Filter 2 still runs so the raw score and
its disagreement remain available for calibration. A finding supported by at least two
distinct specialists with compatible fixes survives Filter 2 even when its raw score is
below 70. Record `gate_reason: "corroboration"`; ordinary threshold survivors record
`gate_reason: "score"`. The quote gate still ran first and exclusions still win later,
so two lenses cannot corroborate an unevidenced or expressly excluded claim into output.

Then dedupe against durable history. A match is a candidate, not proof: verify from the
claim or visible summary text that it is the same defect with a compatible remedy before
suppressing it. **The two arms match on different keys**, because a reviewer's item and a
finding of ours carry different fields — `intake.md` gives `items` a `path` and a `line`
and no anchor at all.

- Same defect as a reviewer's existing ledger claim → **do not post it again.** Link the
  ledger item and handle it there. Match on `path` plus a `line` inside or adjacent to the
  finding's span, then confirm from the claim text that it is the same defect. **Never on
  `site_key`:** an item has none, so the comparison matches nothing every time, and the
  arm that exists to stop us restating a bot's finding back at it fails silently at fleet
  cadence.
- Same defect as a finding we posted on an earlier run → do not post it again; carry the
  restored finding forward. **This** is the arm `site_key` keys, and every restored finding
  carries one or has had it normalized per `intake.md`. A `BLOCKER` is never suppressed
  this way. Post and reconcile it again: a public marker that anyone can copy is not
  authority to retire a blocker.
- Same defect as a finding **we already fixed** → do not post it again. A `fixed` finding
  carries no marker, so the previous-run load cannot restore it and the bullet above never
  fires. **This step owns the lookup**, because it is the first point at which a
  fingerprint exists to look up — Stage 1 has none. Read the `Finding:` trailers off the
  branch by the command in `output.md` and compare the value whole; an exact match
  restores the finding as `fixed`, and anything else leaves it open. A commit that left
  the branch takes its trailer with it, which is the ancestry check for free.
  **Match the fingerprint, not the `site_key`**, and only here: the trailer is a frozen
  string from an earlier run, so an exact comparison is available and a derived key would
  only widen it. Where a trailer's fingerprint differs but its derived `site_key` matches,
  the earlier run fixed a different category's defect at the same anchor — that is a
  candidate for the bullet above, never a fixed match here.
  **A `BLOCKER` is not suppressed this way either**, for a sharper version of the reason
  above: the trailer is a commit message, and on a PR the author writes those.

Every suppression is a real ending. Record it as `dropped`, with the ledger item or
`site_key` it merged into. A suppressed finding with no status sits `open` forever and
reds a clean head.

---

## Filter 2 — independent scoring

**No specialist that found the issue scores it.** Dispatch a separate scoring subagent
per finding that is not any name in `corroborated_by`. Give it the finding, the diff,
the quoted evidence, and the rubric below **verbatim**. The finders are invested in the
finding; the scorer is not, and that is the entire mechanism.

**Strip the corroboration metadata first.** The pass above stamps `corroborated_by`,
`categories`, `gate_reason` and `specialist` onto the finding before this filter runs, so
"give it the finding" would hand the scorer the news that two lenses already agreed. It
anchors upward on that exactly as it would on a previous score, and the raw number stops
being independent of the thing it is supposed to be checked against — which is the whole
reason this filter still runs on a corroborated finding at all. Pass the defect, the
evidence and the fix; withhold who found it and how many.

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
> - **50** — Moderately confident. Verified as real, but it may be a nitpick.
>   Relative to the rest of this change, not important.
> - **75** — Highly confident. Double-checked and verified. The current approach is
>   insufficient. Directly affects functionality, or is explicitly required by a
>   project convention file.
> - **100** — Certain. Double-checked and confirmed as definitely real, with evidence
>   that directly demonstrates it.
>
> **Do not lower the score because the bug is rare, or because the path that reaches
> it is hard to hit.** Score only whether the claim is true. How often it fires is
> judged separately, after you.
>
> If the finding cites a project convention, verify the convention file actually says
> that. Do not take the finder's word for it.
>
> You have not been told any previous score for this finding, and must not ask for
> one. Score it from the evidence alone.
>
> Return only: `{"score": N, "why": "<one sentence>"}`

**Frequency is not scored here.** Filter 3 owns it, and Filter 3 downgrades where a
score kills — so docking a verified finding for rarity kills it before the filter built
to handle it runs. `docs/DESIGN.md` records what this replaced.

### Threshold

**Below 70 dies unless the corroboration pass recorded at least two distinct
specialists with compatible fixes.** There is no "but it's cheap to mention" exception.
Independent convergence is the one alternate evidence path, and it remains visible in
`corroborated_by` rather than being folded into or substituted for the raw score.

**70, because the scale tops out near 88.** Across 38 scored findings the highest score
any scorer returned was 88; no finding reached 90, and none reached the rubric's 100
anchor. An 80 gate against an 88 ceiling passes only the top tenth of the range the
scorer actually uses, which is a far narrower bar than "80 out of 100" reads as. The old
threshold also sat two full steps above the floor `calibration.md` sets for its own
movement rules, on no evidence. Raising it again is one calibration step and needs the
hand sample in `calibration.md`, not a judgement call mid-review.

**The threshold follows the `category` field, never the lens that emitted it.** For a
corroborated finding with multiple `categories`, use the strictest threshold among them;
today they are all 70. A lens
may emit on another's behalf — `security` emits the production-reachable test key as
`category: "money"` when `money` is not dispatched — and once per-category thresholds
exist, that finding is scored against `money`'s number. The category is the claim about
what kind of defect this is; the emitter is an implementation detail of who noticed it.
Scoring by emitter would give one defect two different bars depending on which lens saw
it first, which is the whole reason the handoff stamps a category at all.

**The rubric must stay continuous for that number to mean anything.** A five-value
rubric — 0/25/50/75/100 — admits only 100 under any threshold above 75, silently killing
every "highly confident, verified, directly affects functionality" finding at 75. That is
a live bug in the plugin this rubric came from
([claude-plugins-official #1852](https://github.com/anthropics/claude-plugins-official/issues/1852)),
inherited here verbatim along with the 80 threshold that sat just above the band. If you
ever tighten the rubric back to fixed bands, move the threshold onto a band.

**An unparseable or missing score counts as 100, not 0.** Fail toward keeping the
finding. A scorer that errors out must not silently suppress what it was asked to
judge.

**Watch for a dead scorer.** The failure mode is silent: a scorer that errors on every
call returns unparseable output, every finding counts as 100, and the review looks
unusually decisive. Three signatures, all cheap to check before posting — every finding
in a review scoring exactly 100, no finding ever landing between 70 and 99, or the gate
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

**Store uppercase bare enum values; add punctuation only when rendering a comment.**
`BLOCKER` in the schema and ledger renders as `Blocker:`. The same mapping applies to
the other three values.

| Stored | Rendered | Meaning |
|---|---|---|
| `BLOCKER` | `Blocker:` | Breaks behaviour, leaks data, loses money, or blocks rollback — **and** `likelihood` is `plausible` or better. Merging is wrong. |
| `REQUIRED` | `Required:` | A real defect that should be fixed in this PR. |
| `NIT` | `Nit:` | Minor. The author may decline it without justifying the decision. |
| `FYI` | `FYI:` | No action wanted. Context only. |

Reserve `BLOCKER` for the four named consequences. Everything else is `REQUIRED` at
most. An unlabelled finding reads as mandatory, which is how a review of eleven nits
becomes a day of someone's work.
