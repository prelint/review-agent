# Design

Every decision here traces to a measured failure in two weeks of review-agent logs
(18 Jul – 1 Aug 2026: 2,600 session files, 454 review-agent sessions across 53 PRs).
If a rule has no evidence behind it, it does not belong in this repo.

## Zero dependencies

Requires `git`, `gh`, `python3`. Nothing else — no standalone `jq`, since every
filter runs through `gh --jq`, which is built in.

No gstack, no plugin marketplace, no `~/.claude/skills/...` reads, no `~/.gstack/`
state, no telemetry, no gbrain. The previous skill loaded 165 KB on every
invocation, 46% of which was shared harness preamble that had nothing to do with
reviewing. A review skill should be readable in one sitting by the person who has
to debug it at 2am.

State lives in the repo under review (git history, PR threads) or in a single
run-scoped ledger file. Nothing is written to the user's home directory.

## The five failures this replaces

| Failure | Evidence | Fix |
|---|---|---|
| Only Greptile could steer a review | `select(.user.login == "greptile-apps[bot]")` in the fetch; 62 mentions of Greptile in the old skill, 0 of any other reviewer. Copilot, cubic-dev-ai, cursor, baz-reviewer and github-code-quality all commented on PRs in the window and were never read. | Stage 1 fetches every author. Trust is applied after reading, never at the API call. |
| The loop closed on the founder's desk | 13 times in two weeks the founder pasted a comment back and asked "did you address this?" | Stage 5 cannot finish until every ledger item resolves to a commit, a rebuttal, or a deferral. |
| Dirty worktrees | Old rule, verbatim: *"Never commit, push, or create PRs — that's /ship's job."* 1,347 edits made under it. 11% of sessions ended with an uncommitted code edit; two ended on the words "Fixing it." | One finding, one commit, immediately. An interrupted run leaves a clean tree. |
| Uncapped output | 226 posted comment bodies: median 1,718 chars, p90 4,180, max 10,289. The worst was 10 KB reporting *"0 blocking, 6 informational"*. | Hard caps in Stage 5, and nothing posts when nothing blocks. |
| Everything through Bash | 14,249 Bash calls vs 2,113 Read and 2 Grep. 88 tool errors followed. | Stage 2 requires the native search tools; `gh` and `git` are the only sanctioned shell. |

## What the rewrite dropped

**Removing a mechanism costs the same paragraph as adding one: the alternative, and
why it lost.** Nothing recorded these seven, and five open issues came out of them.

The five failures above were removed on purpose. These were removed by omission —
gstack had them working, the rewrite did not carry them, and no file said so.

Citations are anchor-first, per `specialists/_schema.md`: the quoted string is the
address and the number beside it is a hint. gstack is not vendored here and
`gstack-upgrade` rewrites these files, so the numbers below are only true of the copy
at `~/.claude/skills/gstack/review/` on the day they were taken. The anchors survive.

| gstack has | Where | Here now |
|---|---|---|
| `NO FINDINGS` as an explicit clean result, and a consumer that reads it | `review/specialists/*.md` `If no findings:` :7, `review/SKILL.md` `If output is "NO FINDINGS"` :1380 | Silence, which is the same bytes as a crashed lens ([#13]) |
| A dead or timed-out specialist logs and the run continues on partial results | `review/SKILL.md` `partial results are better than no results` :1370 | No rule ([#13]) |
| A failed reply POST warns and continues | `greptile-triage.md` `If a reply POST fails` :92 | No rule, in the one stage forbidden from reporting false success ([#18]) |
| A malformed state file skips its bad lines and continues | `greptile-triage.md` `never fail on a malformed history file` :57 | No rule ([#18]) |
| The PR comes from the current branch, never an argument | `greptile-triage.md` `PR_NUMBER=$(gh pr view` :13 | A PR number, diffed against local `HEAD`, with nothing comparing the two ([#14]) |
| Prior decisions read back off GitHub by matching markers in our own replies | `greptile-triage.md` `Escalation Detection` :156 | Our own comments are skipped ([#11]) |
| Outcomes append to a per-project and a global history file | `greptile-triage.md` `History File Writes` :182 | Nothing ([#11]) |

Not every gap here is a drop. `gh auth status` is the counter-example worth keeping
straight: `intake.md` lists an unauthenticated `gh` as a reason to refuse the run and
Stage 0 never checks it ([#26]), but gstack has no gate either. Its only use of the
command is platform detection — reached when the remote matches neither `github.com`
nor `gitlab`, and failing it selects git-native commands rather than stopping. That is
a condition this repo invented and did not wire, not a mechanism it inherited and lost.

Two removals were deliberate and got the wrong scope.

**`~/.gstack/` state.** Banned above for good reasons: 165 KB per invocation, 46% of
it harness preamble. That argument is about the *location*. It was applied to the
*function*, and remembering what a previous run decided now has no home.
`reference/calibration.md` reaches the same conclusion from scratch and names the two
places that qualify — the repo and GitHub. Neither is built.

**Skip silently.** gstack treats reviewer triage as additive: if the fetch fails, skip
and say nothing (`greptile-triage.md` `Skip Greptile triage silently` :16).
Inverting that was right, because silence reads as coverage you did not provide. The
inversion reached dispatch and never
reached the return, so `specialists/_schema.md` now says both "never return nothing"
and "output nothing at all if you found nothing".

One more from outside gstack. mattpocock's `code-review` pins its diff to a fixed
point the caller supplies and refuses to run without one
(`skills/engineering/code-review/SKILL.md` `Whatever the user said is the fixed
point` :19). Both ancestors bind the diff to something the caller named. This skill
binds it to whatever is checked out.

[#11]: https://github.com/prelint/review-agent/issues/11
[#13]: https://github.com/prelint/review-agent/issues/13
[#14]: https://github.com/prelint/review-agent/issues/14
[#18]: https://github.com/prelint/review-agent/issues/18
[#26]: https://github.com/prelint/review-agent/issues/26

## Reading the changing review body

Both the old paths watermark on `created_at`. Across all 454 sessions, `updated_at`
was fetched **zero times**, and the PR description was fetched **zero times**.

That is a correctness bug, not a preference. Greptile and prelint post one summary
comment per PR and **edit it in place** on each subsequent run. `created_at` stays
pinned to the first post; only `updated_at` moves. Any watermark that has advanced
past the original post time will never surface the new verdict. The confidence score
changes from 3/5 to 5/5, or from 5/5 to 3/5, and the agent sees neither.

There is a comment in these logs created 2026-04-16 and edited 2026-07-18 — three
months of drift invisible to a `created_at` watermark.

So Stage 1 tracks four moving surfaces, not one:

1. **Top-level comments** — watermark on `max(created_at, updated_at)`.
2. **Inline review comments** — same, plus `position == null` means the line is gone.
3. **Review bodies** (`/pulls/{n}/reviews[].body`) — where a verdict often lives, and
   what "the changing review body" means most literally.
4. **The PR description** (`/pulls/{n}.body`) — never read before, and it is the
   spec the diff is supposed to satisfy.

Each surface is content-hashed. An edit that changes nothing does not re-trigger; an
edit that changes the verdict does.

## Why the PR description is a finding source, not just context

Measured on 23,247 agent-authored PRs: 1.7% had a description that did not match the
diff. Those PRs were accepted 51.7% less often and took 3.5× longer to merge.

Writing code and honestly summarising it are different tasks, and an agent that
satisfies the literal prompt while missing the requirement will still write a
confident description. So description↔diff mismatch gets its own specialist
(`spec-drift`) rather than being folded into a general correctness pass.

## Trust model

The old fleet gated on an allowlist of two bots plus two hand-maintained human logins.
The bot half was wrong outright — it silently dropped five other review bots. The
human half was solving a real problem with the wrong tool.

The replacement is two fields GitHub already sends, and still no config file:
`user.type` splits bot from human, and `author_association` splits repo members from
strangers.

- **Reading** is unconditional. Every comment from every author is fetched and parsed.
- **Repo humans steer.** `OWNER`, `MEMBER` or `COLLABORATOR` can redirect the run.
  Outside contributors cannot — their comments are read and verified like anyone
  else's.
- **Every bot reports.** A bot produces claims, verified against the code, decided on
  evidence.
- **A finding is a finding regardless of author.** A bot's claim and a human's claim
  get identical verification. Tier orders the queue; it never decides whether
  something is examined.

An earlier version trusted every human and deferred the association check. That was
wrong for any public repo: anyone with a GitHub account can comment, so a stranger
could redirect a review. The two mitigations relied on are real but partial — the
nonce sandbox is a convention the model honours rather than a technical barrier, and
the verification gate constrains what *ships*, not what gets *looked at*. Neither
stops a redirect. `author_association` closes it with one predicate and no
maintenance, and a new teammate becomes `directive` the moment they join the repo.

All third-party text is wrapped in a nonce-delimited untrusted block before it
reaches a subagent, which is the defence that actually matters.

### Where the guarantee holds

"Stage 5 cannot finish while any entry is `open`" holds for **one sequential run
against one PR**.

The ledger is per-run state under `.review-agent/`, gitignored, local to the process.
Two agents on the same PR each build their own from their own Stage 1 fetch:

- A comment arriving after run A's Stage 1 is invisible to run A's Stage 5. A closes
  its ledger honestly and the PR still has an open item.
- Both runs may fix the same finding, producing two commits for one problem.
- Neither can see the other's `rebutted` decisions, so one may fix what the other
  argued against.

Local run state is still the right call — a shared ledger needs a lock, and a lock
needs an owner and an expiry, which is the bug class `idempotency` exists to catch.

Two mitigations bound it. Stage 5 re-fetches before reconciling, catching anything
that landed during Stages 2–4 of the *same* run. Stage 0 stops when a prior review
exists at the same head SHA with nothing re-opened, preventing the common
double-dispatch. Neither helps with two runs in flight at once.

**Single run, guaranteed. Concurrent runs, best effort.** If concurrency becomes
routine, the fix is a lease on the PR, not a shared ledger.

## Why the gate is two filters, not one

Stage 3 runs them in series because they catch different things.

**Quote-or-drop** (kept from the old skill, the one genuinely excellent part of it):
a finding cannot ship unless the agent quotes the verbatim line that motivates it.
"Field X doesn't exist on model Y" requires quoting the class body. This kills
hallucinated findings.

**Independent scoring** (from Anthropic's official plugin): a *different* agent, one
that did not find the issue, scores it 0–100 against a rubric passed verbatim, and
anything under 80 dies. The finder is invested in its own finding; the scorer is not.
This kills real-but-worthless findings.

A single filter does one or the other. Both, in series, do both.

## One finding, one commit

The old skill separated fixing from committing because a human was watching and might
want to inspect before it landed. There is no human watching a fleet worker.

Each accepted fix commits on its own with the finding cited in the message. Three
consequences, all wanted: an interrupted run leaves a clean tree; `git log` becomes
the answer to "did you address this?"; and a bad fix reverts without taking four
unrelated fixes with it.

**Settled, 2 Aug 2026.** A review raised that ten accepted findings means ten commits
on the branch and asked whether that had been validated with the humans who merge
them. It has: commit early, commit often is the house stance. No consolidation step,
no batching option, and this is not a per-repo setting. Do not reopen it on commit
count alone.

## Thread resolution is part of closing the loop

Replying to a comment is not resolving it. The old skill replied and stopped, so
threads accumulated and nobody could tell at a glance what was outstanding — which is
the "did you address this?" problem in mechanical form.

Stage 5 resolves the GitHub thread when, and only when, the fix commit exists.
Disagreements are never auto-resolved; a rebuttal is posted and the thread stays open
for a human.

## Specialists: what was missing

The old set was seven (security, testing, performance, maintainability, api-contract,
data-migration, red-team). Against this stack — Django Ninja over Aurora, React 19,
Stripe, Stytch, 19 CDK stacks, LLM pipelines, multi-tenant B2B SaaS — that set has
holes, and every hole below corresponds to a bug that actually shipped.

| New specialist | Why, from the record |
|---|---|
| `tenancy` | Multi-tenant SaaS with an `organizations` table. A query missing tenant scope leaks another customer's data. No existing specialist owned it. |
| `money` | Duplicate charges, a permanently inflated `lifetime_used_cents`, a $642 unbounded ingestion run, "billing users too much per one PR". The highest-cost bug class in the log and it had no owner. |
| `idempotency` | Webhooks, events and sync across Stripe, GitHub and Stytch. "Concurrent same-head finalizers can still post duplicate GitHub inline reviews"; duplicate Sentry references; redelivery handling. |
| `infra-deploy` | 19 CDK stacks. A deploy workflow that omitted a new stack; a `cdk-diff` check green because it never ran; a one-shot production TLS swap with no rollback story. `data-migration` covers the database only. |
| `spec-drift` | The description↔diff mismatch class above, and the product's own thesis: reviewers check whether code is technically correct, not whether it does the right thing. |
| `llm-pipeline` | They ship prompt packages and run models in production. Prompt/consumer drift, a Lambda vendoring prompts by value, token budget ceilings, provider fallback. |
| `observability` | "A silent fleet freeze with no signal anywhere." Does a new failure path emit anything? |
| `silent-failure` | Swallowed exceptions, bare `except`, `|| true`. Ported from `pr-review-toolkit`, the only library with a lens for it. |
| `coherence` | The change is right and what it meets is right and together they are wrong. Found the hard way — see below. |
| `resource-limits` | Missing bounds — rate limits, page caps, concurrency, timeouts, lock scope. `money` owned the financial consequence of unbounded work; nothing owned the operational one, where one tenant saturating a pool or a queue degrades every other. |

Two more from `pr-review-toolkit` are worth porting later and are not urgent:
`comment-analyzer` (comments that no longer describe the code) and
`type-design-analyzer`.

### What the last seven reused, and from where

All seven have landed. This is the record of where each came from, not a plan.

gstack's specialists were 45–60 lines: a scope header, a JSON schema, a flat list of
categories. The **taxonomies were good and ported wholesale** — its `security.md` was
seven categories and ~35 concrete checks.

What they lacked was the half that makes a finding survive Stage 3: no evidence bar, no
failure-scenario requirement, and **no "not a finding" section at all**. A checklist
that says what to look for and never what to ignore is a false-positive generator.

Every port kept the categories and gained the suppression rules.

| Specialist | Ported from | Written fresh |
|---|---|---|
| `security` | gstack `specialists/security.md` — all 7 categories | Suppressions from `exclusions.md` #1–15; evidence bar |
| `testing` | gstack `specialists/testing.md` — all 6 categories | "Not a finding", especially: missing coverage is never a standalone finding |
| `performance` | gstack `specialists/performance.md` + Osmani's N+1 / pagination / unbounded-fetch list | Evidence bar — a perf claim needs a quantity, not an adjective |
| `api-contract` | gstack `specialists/api-contract.md` — already stack-specific to the committed OpenAPI spec | Suppressions; failure scenario |
| `data-migration` | gstack `specialists/data-migration.md` — Aurora and Django specific | Rollback-path check, which `infra-deploy` covers for infra and nothing covered for data |
| `correctness` | gstack `checklist.md` + main skill Step 4 (SQL & Data Safety, Race Conditions, LLM Output Trust Boundary, Shell Injection, Enum & Value Completeness) | Restructure — it is currently prose inside a 105 KB file, not a specialist |
| `maintainability` | Mostly not gstack — its version is thin. Osmani's structural remedies and "does this refactor reduce complexity or relocate it"; Pocock's Fowler smell baseline with the repo-overrides rule | The whole shape |

### Red team earns its own lens

Thirty red-team and adversarial sessions ran in the window. What they produced could
not have come from any checklist, because there was no bullet to match:

| Finding | Why no checklist finds it |
|---|---|
| A no-empty-org invariant that counted **members, not admins** — so the zero-admin dead-end the PR existed to fix survived it | Requires holding the ticket's intent against the implementation |
| Two **forward-only** fixes, correct going forward, leaving the already-broken production cohort unremediated and unmentioned | Requires reasoning about the deployed population, not the diff |
| A Slack alert deduped on message body, so a wave of twelve strandings announced one | Requires asking what two things the key must distinguish |
| A prompt budget capping one half of a payload while the other grew unbounded | Requires asking whether the cap is on the right quantity |
| A VAT status that could never refresh in-session: the mutation wrote back the pre-reset response and a 15-minute `staleTime` invalidated nothing | Spans a mutation, a cache policy and a query — no single lens sees all three |

All the same shape: **locally correct, globally wrong.** Looking harder at the hunk
never finds them.

Three properties made the good sessions good, and are now in the file: start cold with
no other findings; enumerate attacks before hunting evidence, and report the disproved
ones; verify empirically — the strongest ran the command rather than reasoning about
it.

Two changes from gstack's version. **Not gated on diff size** — a five-line guard
change produced two of the best findings here, a 900-line refactor produced none. And
it must **report what it cleared**; a pass that only emits problems reads as a machine
looking for problems.

UX review is deliberately out — it wants a running app, not a diff. A decision, not an
oversight.

## Resource limits are in scope, and the exclusions were wrong

Three of the exclusions — denial of service, rate limiting, memory and CPU exhaustion
— were carried over from
[claude-code-security-review](https://github.com/anthropics/claude-code-security-review)
without checking whether they transfer. They do not.

That list serves a lens whose only job is finding exploitable
vulnerabilities. Resource exhaustion is out of scope there by definition, and it
generates enormous false-positive volume because almost any loop can be framed as a
DoS vector. Both true, and neither survives the move to a general review of a metered
multi-tenant service:

- One tenant's unbounded job saturating a connection pool or a worker fleet degrades
  every other tenant. That is customer-visible whether or not anyone is attacking.
- This codebase has already shipped an ingestion run that cost $642 unchecked, and
  `REVIEW_MAX_BUDGET_USD` exists because the same class bit twice.
- A missing page cap or a lock held across a network call is exactly the kind of
  defect a senior reviewer raises, not a hardening nit.

So items 1, 3 and 4 are narrowed rather than deleted. What stays excluded is the
*speculative framing* that generated the volume — "an attacker could send many
requests", with no named endpoint, caller or shared resource. What comes back is a
specific missing bound with a named blast radius, and it now has an owner in
`resource-limits`, which requires all three before a finding can exist.

## Adopted from upstream open issues

Swept the open issues and PRs of every source repo. Five were review-related and
clearly correct; all five are in.

**A likelihood axis** — [agent-skills #436](https://github.com/addyosmani/agent-skills/issues/436),
[PR #441](https://github.com/addyosmani/agent-skills/pull/441). Severity says what
happens if a finding fires; confidence says whether the claim is true; neither says
whether it fires at all. A finding can be 95% certainly-true and 5% will-ever-happen.
That gap is the dominant LLM-reviewer failure mode. Now Filter 3 in
`verification.md`, with the PR's two refinements:

- **A named condition, not a score.** A score invites reverse-engineering to justify a
  severity already chosen; "fails if two workers process one shard" is something the
  author can settle against the single-consumer invariant.
- **Downgrade, never drop** — a filter the author cannot see reads as "the reviewer
  found nothing" — and `unverified` is never `remote`, because guessing low and
  guessing high are the same error.

This also fixed exclusion #8, which dropped "theoretical" races outright. A named
interleaving is now a `remote`-band finding, not a deletion.

**State the working directory** — [claude-plugins-official #4693](https://github.com/anthropics/claude-plugins-official/issues/4693).
Their reviewer never told the subagent its repo root; mining transcripts found 14
hallucinated roots in 14 runs, mostly the primary checkout when the review was in a
worktree. This fleet reviews inside `/tmp` worktrees almost exclusively, so it would
have hit us harder. Stage 2 passes an absolute `WORKDIR`.

**A diff cannot show an absence** — [superpowers PR #2070](https://github.com/obra/superpowers/pull/2070).
Incomplete sweeps (a constant changed in three places out of four) and missed call
sites are invisible to diff-only reading, and spotting them requires already
suspecting them. Named in `_schema.md`, with the PR's scoping kept: one focused grep
per named risk, never a general crawl.

**Necessity** — [mattpocock/skills #713](https://github.com/mattpocock/skills/issues/713).
`spec-drift` already covers code the spec did not ask for. The gap was hand-rolled
code an installed dependency provides — now an evidence rule in `_schema.md`: cite the
module or manifest entry, and absence from a conventional directory is not evidence.

**Diff prefix hardening** — [claude-plugins-official #4569](https://github.com/anthropics/claude-plugins-official/issues/4569).
`diff.mnemonicPrefix=true` yields `c/`/`w/` instead of `a/`/`b/`, silently dropping
every file in their parser. One `-c` flag.

Not adopted: the routing issues on `agent-skills` (#172, #173) are about two surfaces
competing for one intent, which a single skill does not have; the
`silent-failure-hunter` YAML bug (#4726) is in frontmatter our specialists lack.

## Coherence earns its own lens

Three consecutive findings on this repo's own PR shared one shape, each created by the
fix for the last:

1. A thread-join fix produced `thread_id = null` on failure. Nothing consumed the null.
2. The null case gained an `unresolvable` status. The silence rule four commits back
   counted it as closed and suppressed the warning the status requires.

An external reviewer caught both. Nothing in this skill would have, and the first
attempt at a fix made the ownership problem worse rather than better: the defect
classes went into `specialists/_schema.md`, the shared contract every lens reads.

That is the diffusion failure this repo already diagnosed in gstack. A rule every lens
is supposed to apply is a rule no lens owns, which is exactly why `money`, `tenancy`
and `idempotency` became specialists instead of bullets. The same argument applies
here and was missed the first time.

So `coherence` is a lens, always-on, and it owns four shapes: contradicted rules,
orphaned producers, orphaned consumers, and incomplete sweeps or missed call sites.
All four share one mechanic — the other half is outside the diff, so no diff-only
reader sees the pair. Its evidence bar reflects that: two citations, always. A single
citation is half a finding.

`_schema.md` keeps only the budget rule that genuinely applies to every lens — one
focused grep per named risk, never a general crawl. `red-team` lists the four shapes
under "not a finding" so it stops competing for them.

## Known limits

**Cost scales with lens count, not diff size.** Every lens is dispatched on every
review and answers for itself, which is what removed the drifting dispatch table. The
price is eighteen calls on a one-line diff. On this repo that is the right trade. For a
high-volume repository it may not be, and a fast-path bypass for trivially small diffs
is the obvious lever — a deployment question, not a design one. Not built.

**Stage 4 has only ever run on this repo.** Sequencing works at small n on a codebase
the agent knows. That is not evidence it works on an unfamiliar one, and a clean result
still means the lenses found nothing rather than that the pipeline is proven. The count
is `git log --grep='Finding:'` and is not kept here as a number: it was written as a
number twice, in two files, and the two disagreed within half an hour.

## Calibration

Not implemented. `reference/calibration.md` has the mechanism and says so in its first
line.

The signal is **outcome, never reactions**: did a commit cite the finding's
fingerprint, was it rebutted with evidence, was it deferred to an issue. All three are
already recorded — Stage 4 writes the fingerprint into every commit message, and Stage
5 resolves threads only against a real SHA.

Reactions were in an earlier draft and are gone. The reviewers and PR authors here are
mostly agents, and agents do not click 👍. Even with humans the signal was ambiguous:
👍 on GitHub reads as "I agree", not "this finding was accurate".

Thresholds will live in a committed file, because a stateless agent's memory has to be
the repo.
