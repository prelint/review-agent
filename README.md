# review-agent

Reviews a pull request, fixes what it finds, and proves it closed every open comment
before it posts.

Needs `git`, `gh`, `python3`. Nothing else.

## What it does

1. **Reads everything.** Every reviewer, bot or human. The PR description too.
2. **Runs 18 lenses** in parallel — security, money, tenancy, migrations, and more.
3. **Verifies twice.** A finding must quote its evidence, then pass a scorer that
   didn't find it.
4. **Fixes what it accepts.** One finding, one commit, immediately.
5. **Proves it's done.** Every comment ends up fixed, rebutted, deferred,
   informational, or flagged unresolvable. Then it replies, resolves the thread, and
   posts — or stays quiet if nothing blocks and nothing is unresolvable.

Stage detail: [`SKILL.md`](SKILL.md), then [`reference/`](reference/).

## Why it exists

Two weeks of logs: 2,600 sessions, 454 reviews, 53 PRs. Five things kept going wrong.

| Broken | Now |
|---|---|
| Read one bot's comments. Five other review bots were ignored. | Reads every author. |
| Watermarked on `created_at`, so a bot editing its verdict in place was invisible. | Watermarks on edits. |
| Never read the PR description. | Reads it, and checks the diff against it. |
| Forbidden from committing, so 11% of runs left uncommitted edits. | Commits each fix as it makes it. |
| No output cap. Worst comment was 10,289 characters with nothing blocking. | 2,000 characters, five findings, or silence. |

Evidence for each: [`docs/DESIGN.md`](docs/DESIGN.md).

## The two ideas that matter

**The ledger.** Stage 1 lists every open reviewer comment. Stage 5 can't finish while
one is still open. That is the mechanical answer to "did you address this?" — asked
thirteen times in two weeks because nothing could answer it. Guaranteed for one
sequential run on one PR; two runs at once are best effort, and
[`docs/DESIGN.md`](docs/DESIGN.md) says where the line is.

**Two filters, not one.** Quote-or-drop kills findings that aren't real. A separate
scorer kills findings that are real and not worth your time. Either alone leaves half
the noise.

## The lenses

Always on: `coherence` · `correctness` · `spec-drift` · `silent-failure` ·
`maintainability` · `testing`

On their ground: `security` · `tenancy` · `money` · `idempotency` · `resource-limits` ·
`performance` · `api-contract` · `data-migration` · `infra-deploy` · `llm-pipeline` ·
`observability` · `red-team`

Two are worth calling out. **`coherence`** catches what a diff cannot show: a new rule
contradicting an old one, a state nothing consumes, a rename done in three files out of
four. **`red-team`** has no checklist — it caught an invariant counting the wrong thing
and two fixes that left already-broken production data unmentioned.

## Trust

Repo members steer, everyone else reports. Split on `user.type` and
`author_association`, both sent by GitHub. No config, no list to maintain.

Reading is never gated. A bot's finding gets the same verification as a maintainer's —
evidence decides, not the login.

## Status

Ran end to end once, on its own PR #10. Found eight things, fixed eight, one commit
each. One was a blocker: three lenses would have silently skipped themselves.

Stages 1–3 have run many times. Stage 4 has run once. A clean result means the lenses
found nothing, not that the pipeline is proven — don't use it as a merge gate yet.

Not built: per-repo overrides, and calibration
([`reference/calibration.md`](reference/calibration.md) says plainly what is missing).

## Contributing

[`CONTRIBUTING.md`](CONTRIBUTING.md). Short version: an agent reads this on every run,
so every word costs. Cut the fat, keep the function.

Every PR here gets reviewed by this skill, including PRs that change it.

## Built on

MIT and Apache-2.0 work by others — the scoring rubric, the exclusion list, the
verification gate, several lens taxonomies. Credited file by file in
[`NOTICE.md`](NOTICE.md).
