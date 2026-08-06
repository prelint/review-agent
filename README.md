# review-agent

Reviews a pull request, fixes what it finds, and proves it closed every open comment
before it posts.

Needs `git`, `gh`, `python3`. Nothing else.

## Install

```
curl -fsSL https://raw.githubusercontent.com/prelint/review-agent/main/install.sh | bash
```

Clones into `~/.claude/skills/review-agent` and adds two rules to `permissions.allow`
in `~/.claude/settings.json`. Claude Code then reads this skill's files and runs its
update script without prompting.

After that the skill keeps itself current. Each run starts with `self-update.sh`,
which fast-forwards the clone from `main`, at most once every six hours. Offline it
stays quiet and the review runs on the version it has. A re-run of `install.sh` also
updates.

An install from before self-update exists never gains it on its own: the pull is the
one path that could deliver the update step, and the old SKILL.md never pulls. Run
`install.sh` once more on such an install. That adds the update path and the
permission rule it needs.

It backs up `settings.json` before writing, keeps its file mode, and refuses to touch it
if it is not valid JSON. If it is a symlink, the write follows it rather than replacing
it, so a dotfiles repo stays intact.

Updating only ever fast-forwards `main` from this remote. A checkout on another branch
or another remote is left alone. The self-update also skips a checkout with local
edits.

To read the script before running it, clone first:

```
git clone https://github.com/prelint/review-agent ~/.claude/skills/review-agent
~/.claude/skills/review-agent/install.sh
```

Restart Claude Code, then `/review-agent`.

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
| No output cap. Worst comment was 10,289 characters with nothing blocking. | 2,000 visible characters, five findings, or silence. |

Evidence for each: [`docs/DESIGN.md`](docs/DESIGN.md).

## The two ideas that matter

**The ledger.** Stage 1 lists every open reviewer comment, and Stage 3 adds every
finding of our own. Stage 2 also records which lenses answered clean or cleared and
what they checked. Stage 5 can't finish while a claim or finding is still open. That is
the mechanical answer to "did you address this?" — asked thirteen times in two weeks
because nothing could answer it. Guaranteed for one sequential run on one PR; two runs
at once are best effort, and
[`docs/DESIGN.md`](docs/DESIGN.md) says where the line is.

**Two filters, not one.** Quote-or-drop kills findings that aren't real. A separate
scorer kills findings that are real and not worth your time. Independent lenses that
converge on one compatible fix can carry it through the score threshold, with both the
raw score and the convergence retained. Either filter alone leaves half the noise.

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

Repo members steer priorities within the selected PR; everyone else reports. The run's
integrity and safety rules stay non-overridable at every tier. Split on `user.type` and
`author_association`, both sent by GitHub. No config, no list to maintain.

Reading is never gated. A bot's finding gets the same verification as a maintainer's —
evidence decides, not the login.

## What it assumes about your repo

Nothing on disk survives a run — `.review-agent/` is gitignored. What has to outlive one
lives in two places GitHub already keeps: the markers in the summary comment, and a
`Finding:` trailer on each fix commit. That is why the git workflow below matters at all.

- **It pushes to the PR branch** — `git push origin HEAD`, never a force-push, never a
  rewrite, never another branch. A fork PR needs *Allow edits by maintainers*. Nothing in
  the record shows that path being run.
- **Rebase or force-push the branch and its fixes re-open.** The trailer leaves with the
  commit, and the next run reads that as the fix being gone. That is the intended
  behaviour — it cannot tell a rebase from a dropped fix, and re-opening is the safe
  guess — but it costs a re-review.
- **Squash on merge is fine for review, not for measurement.** A run reads the PR branch,
  which still holds every commit while the PR is open. Squashing collapses the trailers
  into one message, so outcomes read back from merged history land in the unknown bucket.
  [`reference/calibration.md`](reference/calibration.md) says where that bites.
- **It authenticates as a user, not a GitHub App.** `SELF` comes from `gh api user`,
  which 403s for an App — and `SELF` is how a run finds its own last comment.
- **One run at a time per PR.** Concurrent runs on the same PR are best effort.

## Status

Every run has been on this repo, most on its own PR #10. For the count, ask git:
`git log --grep='Finding:' | wc -l`. A number written here goes stale inside a day — the
last one did, and disagreed with [`docs/DESIGN.md`](docs/DESIGN.md).

The first end-to-end run found eight things and fixed eight, one commit each. One was a
blocker: three lenses would have silently skipped themselves.

Stage 4 has never run against an unfamiliar codebase — different test environment,
different layout, a failing test it has to write. A clean result means the lenses found
nothing, not that the pipeline is proven. Don't use it as a merge gate yet.

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
