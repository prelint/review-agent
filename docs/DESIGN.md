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
run-scoped ledger file. A run writes nothing to the user's home directory outside
the skill's own install.

## Self-update

Of the four repos this skill was ported from, three ship no update path at all.
Installed copies drift from upstream until a person notices. gstack is the
exception. Its machinery is heavy: a version check in every skill preamble, a
four-option consent prompt, snooze state with backoff, and telemetry.

`self-update.sh` replaces that with one fast-forward pull before Stage 0. The
pinned clone makes the consent prompt unnecessary. install.sh guarantees a clean
checkout of our `main`, so a fast-forward cannot conflict. The README says the
skill updates itself, so the user consents at install. The script refuses any
other checkout: wrong remote, wrong branch, or local edits. It checks the remote
at most once every six hours, stays quiet offline, and exits 0 on every path. A
stale skill still reviews. After an update, SKILL.md restarts from the top,
because the copy in context predates the pull. The throttle stamp lives inside
the clone's own `.git/`, so the tree stays clean.

The alternative was a SessionStart hook, gstack's team mode. It adds no per-run
latency, but it runs in every project on every session, whether or not the skill
runs. Pull-on-invoke matches the scope of one skill.

Main is the release channel, and this repo treats it as stable. Self-update ships
every commit on main to every install inside six hours, so the channel policy is
part of the mechanism. Every change reaches main through a PR, and this skill
reviews every PR before merge. Work that is not ready for every install stays on
its branch.

## The five failures this replaces

| Failure | Evidence | Fix |
|---|---|---|
| Only Greptile could steer a review | `select(.user.login == "greptile-apps[bot]")` in the fetch; 62 mentions of Greptile in the old skill, 0 of any other reviewer. Copilot, cubic-dev-ai, cursor, baz-reviewer and github-code-quality all commented on PRs in the window and were never read. | Stage 1 fetches every author. Trust is applied after reading, never at the API call. |
| The loop closed on the founder's desk | 13 times in two weeks the founder pasted a comment back and asked "did you address this?" | Stage 5 cannot finish until every ledger item resolves to a commit, a rebuttal, or a deferral. |
| Dirty worktrees | Old rule, verbatim: *"Never commit, push, or create PRs — that's /ship's job."* 1,347 edits made under it. 11% of sessions ended with an uncommitted code edit; two ended on the words "Fixing it." | One finding, one commit, immediately. An interrupted run leaves a clean tree. |
| Uncapped output | 226 posted comment bodies: median 1,718 chars, p90 4,180, max 10,289. The worst was 10 KB reporting *"0 blocking, 6 informational"*. | Hard caps in Stage 5, and nothing posts when nothing blocks. |
| Everything through Bash | 14,249 Bash calls vs 2,113 Read and 2 Grep. 88 tool errors followed. | Stage 2 requires the native search tools; `gh`, `git`, and the pre-stage self-update are the only sanctioned shell. |

## What the rewrite dropped

**Removing a mechanism costs the same paragraph as adding one: the alternative, and
why it lost.** Nothing recorded these seven, and five open issues came out of them.

The five failures above were removed on purpose. All seven below were removed by
omission — gstack had them working, the rewrite did not carry them, and no file said
so. Two deliberate decisions sit behind four of the seven, and both were right about
the thing they were aimed at and wrong about what they took with them; they are the
two paragraphs under the table, not extra rows.

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
| The PR comes from the current branch, never an argument | `greptile-triage.md` `PR_NUMBER=$(gh pr view` :13 | A PR number, and Stage 0 refuses to run unless that PR's head is reachable from `HEAD` and the tree is clean (closed, [#14]) |
| Prior decisions read back off GitHub by matching markers in our own replies | `greptile-triage.md` `Escalation Detection` :156 | Our own comments are skipped ([#11]) |
| Outcomes append to a per-project and a global history file | `greptile-triage.md` `History File Writes` :182 | Nothing ([#11]) |

Not every gap here was a drop. `gh auth status` is the counter-example worth keeping
straight: `intake.md` listed an unauthenticated `gh` as a reason to refuse the run and
Stage 0 never checked it ([#26], now wired), but gstack has no gate either. Its only use
of the command is platform detection — reached when the remote matches neither
`github.com` nor `gitlab`, and failing it selects git-native commands rather than
stopping. That was a condition this repo invented and did not wire, not a mechanism it
inherited and lost.

The two decisions, and the rows each one cost.

**`~/.gstack/` state** — rows six and seven. Banned above for good reasons: 165 KB
per invocation, 46% of it harness preamble. That argument is about the *location*. It
was applied to the *function*, and remembering what a previous run decided now has no
home. `reference/calibration.md` reaches the same conclusion from scratch and names
the two places that qualify — the repo and GitHub. Neither is built.

**Skip silently** — rows one and two. gstack treats reviewer triage as additive: if
the fetch fails, skip and say nothing (`greptile-triage.md` `Skip Greptile triage
silently` :16). Inverting that was right, because silence reads as coverage you did
not provide. The inversion reached dispatch and never reached the return, so
`specialists/_schema.md` now says both "never return nothing" and "output nothing at
all if you found nothing".

One more from outside gstack. mattpocock's `code-review` pins its diff to a fixed
point the caller supplies and refuses to run without one
(`skills/engineering/code-review/SKILL.md` `Whatever the user said is the fixed
point` :19). Both ancestors bind the diff to something the caller named. This skill now
does too: the caller names a PR, and Stage 0 stops unless the checkout contains that
PR's head ([#14]).

### What the marker budget dropped

Four mechanisms went when the 2,000-character cap was redefined to measure visible
content only ([#23]). The cap and the markers had been contradictory: every finding and
every threadless item was required to carry one, and one measured run spent 3,088
characters on them before a single visible character.

| Dropped | What it did | What does its job now |
|---|---|---|
| The marker on a `fixed` finding | carried the ending across runs so the finding was not re-found | the `Finding: <specialist>/<fingerprint>` commit trailer, read by key and compared whole |
| The marker on an all-informational threadless item | carried the classification across runs | nothing — the item is reclassified from scratch, which costs one verification pass and cannot lose a fix, rebuttal or deferral, since none of those is informational |
| "Zero findings carried while one of our summary comments exists" as a refusal | caught a summary whose markers we failed to read | `prior.sentinel`, whose absence on a `SELF` top-level comment is itself a refusal |
| "Never the markers" in the cut order | kept the visible budget from eating durable state | nothing needs it — the visible cap no longer measures the trailer, so the cut order never reaches it |

**The substring hazard is closed, and it took two passes.** Row one made the commit
message the only record of a fix, and the first attempt still matched it with
`git log --grep`. That is a substring test: a bare fingerprint hit any longer fingerprint
on the same path, and adding the `Finding: ` prefix did not anchor it either, because an
anchor may itself contain a colon — so one whole trailer could be a prefix of another and
the shorter finding was suppressed unfixed. `reference/output.md` now asks git for the
trailer by key, with `%(trailers:key=Finding,valueonly)`, and compares the value with
`==`. No substring match remains on this path, and there is no pattern to escape.

**Nothing bounds the raw comment body.** Row four removed the only rule that constrained
the trailer, and the visible cap deliberately does not. GitHub's issue-comment limit is
65,536 characters; a trailer would need roughly 350 markers to reach it, which is about
twenty times the largest run measured, so this is recorded rather than fixed. If a PR ever
gets there, the edit that carries every non-fixed finding fails and takes the run's
durable state with it.

**The trailer recovery is not constrained to our own commits.** It reads any commit
reachable from the head, and on a PR the author writes those. The marker path refuses a
forged marker by requiring `author == SELF`; this path has no equivalent, because a commit
message cannot be made to prove authorship. `verification.md`'s `BLOCKER` carve-out now
names this path, so a blocker is never closed on a trailer match alone; a non-blocking
finding still can be. What remains is a mistake-catcher rather than a boundary, which is
the same conclusion `SKILL.md` reaches about its stacked-commit gate. The gap predates
this change — it is recorded here because dropping row one left nothing else to contradict
a forged trailer.

[#11]: https://github.com/prelint/review-agent/issues/11
[#13]: https://github.com/prelint/review-agent/issues/13
[#14]: https://github.com/prelint/review-agent/issues/14
[#18]: https://github.com/prelint/review-agent/issues/18
[#23]: https://github.com/prelint/review-agent/issues/23
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
- **Repo humans steer within the selected PR.** `OWNER`, `MEMBER` or `COLLABORATOR` can
  redirect priorities. They cannot override the run's integrity or safety rules;
  `reference/intake.md` owns that list. Outside contributors cannot steer — their
  comments are read and verified like anyone else's.
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

The ceiling is deliberate. Association establishes who may steer; it does not make a
compromised account safe or turn quoted third-party text into policy. The review's
integrity gates and repository-safety rules therefore remain non-overridable for every
tier.

**The ceiling is policy the agent follows, not a mechanism that stops it** — the same
footing as the nonce sandbox above, and the same limit. Nothing outside the run can
enforce it: a repository that wants a binding gate needs the commit status of
`reference/output.md`, or its own CI. Anyone adding to the list is writing
self-enforcing policy, and should say so in the same breath.

All third-party text is wrapped in a nonce-delimited untrusted block before it
reaches a subagent, which is the defence that actually matters.

### Where the guarantee holds

"Stage 5 cannot finish while any entry is `open`" holds for **one sequential run
against one PR**.

The ledger is per-run state under `.git/review-agent/`, which git never tracks, local to
the process. Two agents on the same PR each build their own from their own Stage 1 fetch:

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

### GitHub is the ledger that survives

Run state does not reach the next run. The fleet gives each PR a fresh worktree, and
`git worktree remove` deletes `.git/review-agent/` with it. So the *next* run started
cold: every item took the "No previous hash → New item" row, and `substance_hash` — the
field built to tell a typo from a new claim — had nothing to compare against. Worse,
intake skipped `author == SELF`, which threw away the only record of what the last run
decided. On PR #10 that was six discarded comments, two of them our own prior verdicts.

The record was already there. Stage 5 replies in every thread and resolves what it
fixed, so Stage 1 rebuilds the last ledger by parsing its own markers back. The
alternative was committing the ledger to the repo, which puts run state in the diff of
every PR it reviews and makes two concurrent runs fight over a tracked file. GitHub
already stores exactly this, keyed by comment, visible to a human, and free.

`SELF` comes from `gh api user --jq .login`, and a marker counts only where all three of
authorship, position and shape agree: `author == SELF`, in the comment's trailer and not
inside a quote, parseable JSON. The first draft required the marker alone, on the reasoning that a human
running this under their own token has their own comments arrive as `SELF`. That reasoning
is right and the rule it produced was not — it made the marker sufficient rather than
necessary, so anyone able to comment could mint one, and `substance_hash` is computable
from a public body and a pinned `normalise()`. A forged `fixed` would have closed a
reviewer's blocker without touching the code.

Position carries the rest. GitHub's Quote reply copies our body, HTML comments included,
into somebody else's words, and under a human token those words arrive as `SELF` too.
Requiring the trailer, and rejecting `>`-quoted lines, separates a record we wrote from a
record someone quoted. The first draft of this said "last line", which was wrong in the
other direction: the summary carries a dozen markers and only one can be last, so it
silently read one and dropped the rest.

The residual is an account compromise, which is already game over. There is no signing
key here because there is nowhere to keep one: `DESIGN.md` bans home-directory state, and
a secret in the repo is not a secret.

## The ledger holds our findings too

Nine findings, nine commits, and `pr-10.json` recorded none of them. The file had one
array, `items`, so intake had a ledger and the review did not. A finding
cut by the five-finding cap or suppressed by the silence rule left no trace anywhere,
and `surviving_blockers` was an integer Stage 4 decremented by hand with nothing
checking a decrement against a real fix.

So `findings` is a second array in the same file, reconciled the same way. The
alternative was a separate artifact for our side of the review; it lost because Stage 5
would then have two files to close and one of them to forget. The blocker count is now
computed from that array — `BLOCKER`, and neither `fixed` nor `rebutted` — instead of
maintained beside it, for the same reason the run count below is not written here as a
number.

`coverage` is a third, run-local array. It holds validated `clean`, `cleared`, and
`not-dispatched` answers so the evidence that a lens looked is not discarded merely
because it found no defect. Coverage has no reconciliation status and is not restored
across runs; Stage 5 reports its full checked detail in the session and a compact lens
list whenever it posts a summary.

## Why the gate is two filters, not one

Stage 3 runs them in series because they catch different things.

**Quote-or-drop** (kept from the old skill, the one genuinely excellent part of it):
a finding cannot ship unless the agent quotes the verbatim line that motivates it.
"Field X doesn't exist on model Y" requires quoting the class body. This kills
hallucinated findings.

**Independent scoring** (from Anthropic's official plugin): a *different* agent, one
that did not find the issue, scores it 0–100 against a rubric passed verbatim, and
anything under 70 dies unless at least two independent lenses already converged on the
same compatible fix. The finder is invested in its own finding; the scorer is not. This
kills real-but-worthless findings without discarding the stronger signal of independent
convergence.

A single filter does one or the other. Both, in series, do both.

### Convergence is evidence, not merely redundancy

Fingerprints keep their historical `path:anchor:category` shape for markers,
calibration, and fix commits. Dedupe instead uses a category-free `site_key` of
`path:anchor`; putting category in the old key made two lenses' cross-category agreement
nearly impossible to detect. Compatible findings at one site are represented once with
every supporting category and specialist attached. Incompatible fixes stay separate.

The independent scorer still runs and its raw number is preserved. A corroborated
finding may survive below 70, recorded with `gate_reason: corroboration`, so later
calibration can see the disagreement instead of hiding it behind an inflated score. The
quote gate runs before convergence and the exclusion blocklist runs after scoring; two
lenses cannot vote an unevidenced or excluded claim into output.

### Rarity left the score rubric

The rubric used to score frequency as well as truth: its 50 anchor read "or rare in
practice" and its 75 anchor required "very likely to be hit in practice". Filter 3 then
judged frequency again. Because Filter 3 downgrades where a score kills, a verified
finding that was merely hard to reach died at Filter 2, before the filter built for it
ever ran.

The evidence was a 38-finding sample. Nine landed at 68-78 — verified true, docked for
rarity, all dead. Two had to be rescued by hand against the gate: a removed `--clean`
flag that argparse silently abbreviated into `--clean-only`, wiping a developer's seeded
data and exiting 0; and an alarm detector that could not report its own death, where the
`except` branch warns, reaches no page and no Sentry issue, and `NOT_BREACHING` keeps the
alarm green. Both are what Filter 3's `remote` band exists to downgrade rather than drop.

Removing rarity from the score puts the whole frequency judgement on Filter 3. That is
where it was designed to sit, and the open risk is calibration rather than architecture:
findings that used to die at 68-78 now reach Filter 3, so a loose `remote`/`plausible`
call there raises output volume. Nothing measures that split today.

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

### Silence had to stop being a legal answer

`_schema.md` carried both rules at once: never return nothing, and output nothing if you
found nothing. So a lens that died and a lens that passed produced identical bytes, and
the orchestrator counted both as coverage.

The dogfooded review of PR #31 supplied the case while the fix was being written.
`coherence` — always-on, and the owner of every defect no other lens sees — died
mid-response and returned an empty string. Eighteen lenses ran, seventeen answered, and
nothing in the skill could tell.

Three answers now, and an empty response is none of them. gstack had this on line 7 of
every specialist (`If no findings: output NO FINDINGS`) and in its orchestrator ("if any
specialist subagent fails or times out, log the failure and continue"). The taxonomies
were ported here and neither of those was — which is the second time a port kept the
checklist and dropped the part that made it trustworthy.

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
