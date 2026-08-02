# review-agent

A pull-request review skill that reads every reviewer, verifies every finding twice,
commits each fix on its own, and proves the loop is closed before it posts.

Standalone. Requires `git`, `gh`, `jq`, `python3` and nothing else — no plugin
marketplace, no shared harness, no state in `$HOME`.

## Why

Built from a forensic audit of two weeks of review-agent logs (18 Jul – 1 Aug 2026:
2,600 session files, 454 review sessions across 53 PRs). Five measured failures drove
every decision; they are documented with their evidence in
[`docs/DESIGN.md`](docs/DESIGN.md).

The short version:

- The previous reviewer filtered comments to one bot at the API call. Copilot,
  cubic-dev-ai, cursor, baz-reviewer and github-code-quality all commented on PRs in
  that window and were never read.
- It watermarked on `created_at` and fetched `updated_at` zero times — so a bot that
  edits its summary comment in place could change its verdict invisibly.
- It never read the PR description at all.
- Its own rules forbade committing, so 11% of sessions left an uncommitted code edit.
- Nothing capped output. Median posted comment 1,718 characters; worst was 10,289,
  reporting zero blocking issues.

## The five stages

| Stage | Does | Reference |
|---|---|---|
| 0 | Bind the run, resolve the diff base, fail early | `SKILL.md` |
| 1 | Read every reviewer and all four mutating surfaces; write the ledger | [`reference/intake.md`](reference/intake.md) |
| 2 | Dispatch specialist lenses in parallel, 400 words each | [`specialists/`](specialists/) |
| 3 | Quote-or-drop, then independent scoring at 0–100, then exclusions | [`reference/verification.md`](reference/verification.md) |
| 4 | Fix accepted findings — one finding, one commit, immediately | `SKILL.md` |
| 5 | Reconcile the ledger, resolve threads, post or stay silent | [`reference/output.md`](reference/output.md) |

Two ideas carry most of the weight.

**The ledger.** Stage 1 writes one entry per open reviewer item. Stage 5 cannot finish
while any entry is `open`. That is the mechanical answer to "did you address this?" —
asked thirteen times in two weeks because nothing could answer it. The guarantee is
scoped to a single sequential run; concurrent runs on one PR are best effort, and
`docs/DESIGN.md` says exactly where the line is.

**Two filters, not one.** Quote-or-drop kills findings that are not real. Independent
scoring — by an agent that did not find the issue — kills findings that are real and
not worth the author's time. Either alone leaves half the noise.

## Specialists

Written: [`tenancy`](specialists/tenancy.md), [`money`](specialists/money.md),
[`idempotency`](specialists/idempotency.md),
[`infra-deploy`](specialists/infra-deploy.md),
[`spec-drift`](specialists/spec-drift.md),
[`llm-pipeline`](specialists/llm-pipeline.md),
[`observability`](specialists/observability.md),
[`silent-failure`](specialists/silent-failure.md),
[`resource-limits`](specialists/resource-limits.md),
[`coherence`](specialists/coherence.md),
[`red-team`](specialists/red-team.md).

The first nine fill gaps that produced real bugs in the record and that no existing
library covered. `docs/DESIGN.md` names the bug behind each one.

`red-team` is the one lens with no checklist, and on the evidence it is the highest
yield of the set — it caught an invariant counting the wrong thing, two forward-only
fixes that left broken production data unmentioned, and a dedup key that collapsed a
twelve-item alert wave into one message. None of those are findable from a bullet
list. It runs on risk surface, never on diff size.

## Status

Done: design, `SKILL.md`, all four `reference/` files, the specialist contract, and
the eleven specialists above.

**Not yet written** — `SKILL.md` dispatches these and the files do not exist:
`correctness`, `security`, `testing`, `performance`, `maintainability`,
`api-contract`, `data-migration`. They are ports of the previous set, rewritten to
`specialists/_schema.md`. Until they land, Stage 2 skips them and names the skip in
its summary.

**Do not treat this as a merge gate yet.** `security` and `correctness` are among the
missing lenses, so a clean review currently means "the nine written lenses found
nothing", not "this was reviewed". That is fine for a fleet reading the skip notice;
it is misleading to a human treating a green review as approval.

Also outstanding: a `REVIEW.md`-style per-repo override, and `comment-analyzer` /
`type-design-analyzer` from Anthropic's `pr-review-toolkit`.

Trust needs no configuration and no maintained list: repo members steer, everyone
else reports. Split on `user.type` plus `author_association`, both sent by GitHub on
every comment. See [`reference/intake.md`](reference/intake.md#trust-tiers).

## Contributing

[`CONTRIBUTING.md`](CONTRIBUTING.md). The short version: an agent reads this on
every run, so every word costs context. Cut the fat, keep the function.

## Sources

Approaches evaluated and borrowed from, with what was taken. Licences and attribution
are in [`NOTICE.md`](NOTICE.md) — all MIT or Apache-2.0.

- Anthropic official `code-review` plugin — the 0–100 rubric passed verbatim to a
  separate scorer, the pre-post eligibility re-check, the false-positive catalog.
- A security-only exclusion list — the starting point for `reference/exclusions.md`,
  with three items narrowed. Its DoS / rate-limiting / resource-exhaustion exclusions
  suit a lens that only hunts exploitable vulnerabilities; on a metered multi-tenant
  service a missing bound degrades other tenants and bills the customer, so the defect
  class comes back and `resource-limits` owns it. Only the speculative framing stays
  excluded.
- Anthropic [Code Review docs](https://code.claude.com/docs/en/code-review) —
  severity markers, nit caps, `REVIEW.md` as a per-repo override, thread
  auto-resolution on fix. Its 👍/👎 rating loop was considered and rejected: the
  reviewers and authors here are mostly agents, and agents do not click reactions.
- Superpowers `receiving-code-review` — source-agnostic feedback handling, verify
  before implementing, clarify all before implementing any, reply in thread.
- Matt Pocock `code-review` — Standards and Spec as axes that never rerank against
  each other; word caps in the subagent brief.
- Addy Osmani `code-review-and-quality` — severity prefixes, "one structural problem
  and ten nits means the structural problem is the review".
- Anthropic `pr-review-toolkit` — `silent-failure-hunter`, and two more to port.
- gstack `/review` — the quote-or-drop verification gate, which is the single best
  idea in it.
