# Stage 3: The gate

Two filters in series. Neither substitutes for the other.

Filter 1 kills findings that are not real. Filter 2 kills findings that are real and
not worth the author's time. A single filter does one or the other.

---

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
> raising on this pull request.
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
> Return only: `{"score": N, "why": "<one sentence>"}`

### Threshold

**Below 80 dies.** No exceptions, no "but it's cheap to mention".

Per-category thresholds are the plan, not the present. Today every category uses 80.

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

Findings carry a `fingerprint` of `path:line:category`.

- Same fingerprint from two specialists → keep the one with better evidence, record
  both categories on it.
- Same `path:line`, different category → keep both only if they propose different
  fixes. If the fix is the same, they are one finding.
- Same finding as a reviewer's existing comment in the ledger → **do not post it
  again.** Link the ledger item and handle it there. Restating a bot's finding back
  at it was a real source of noise.

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
