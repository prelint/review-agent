# Stage 5: Close and post

Nothing is posted until the ledger reconciles. That is the whole point of this stage.

The failure it replaces: thirteen times in two weeks the founder pasted a reviewer
comment back into a session and asked whether it had been handled. There was no
artifact that could answer.

---

## 1. Re-fetch

Re-run the Stage 1 fetch into a new absolute directory. All of Stage 2–4 took time; the
PR moved, but the raw Stage 1 snapshot is still the before-state and must not be overwritten:

```bash
STAGE1_FETCH_DIR="$RUN_DIR/fetch-stage1"
FETCH_DIR="$RUN_DIR/fetch-stage5"
mkdir -p "$FETCH_DIR"
```

Run `reference/intake.md`'s fetch commands with that `FETCH_DIR`, then compare the two
directories. Do not infer the before-state only from the ledger: the raw bodies, timestamps,
thread state and PR metadata are the evidence for whether an item moved.

- New comments since Stage 1 → new ledger items. Process them, or record them
  `deferred` with a reason and say so in the summary. Silently ignoring them is how
  the loop stayed open.
- Changed `substance_hash` on any existing item → it re-opens, even if it was `fixed`.
  A `body_hash` that moved alone is a typo or a reformat: store it and leave the item
  closed. The full table is in `intake.md`.
- Changed `pr_substance_hash`, and `stage5_reentries` is `0` → re-run `spec-drift`
  before continuing. Once the counter is `1` the sub-section below owns this case and
  bars the second run; without the qualifier the two instructions contradict each other
  on exactly the pass the bound exists for.

### One re-entry, then defer

**Stage 5 may return to Stages 2–4 once per run.** Collect every new or changed item from
one re-fetch into a batch before deciding:

1. When `stage5_reentries` is `0`, set it to `1` in the ledger, process the whole batch
   through the required earlier stages, then restart this section and re-fetch once more.
2. When `stage5_reentries` is already `1`, do not return again. Classify the late batch;
   `informational` claims stay informational, and every actionable new or changed claim is
   `deferred` with the reason `arrived after the bounded Stage 5 re-entry` and an issue
   link. A changed PR description is a changed item under the same rule — it is the
   `description` item `intake.md` defines, and its claim is where that reason and that
   issue link go; do not launch `spec-drift` a second time.
3. Name those deferrals in the summary, **in the author's terms, not these ones**. The
   ledger's `reason` is machine-traceable and stays as written; the summary line says what
   happened and what to do about it — "arrived while this run was finishing and was not
   reviewed — re-run the agent to pick it up". A reader who does not know this skill has
   stage numbers gets a fact they can act on instead of one they cannot. They are closed
   ledger statuses, not permission to imply that the late changes were reviewed.

The issue link is the one section 2 already specifies: fold into an open issue on the same
surface before opening a new one. There is no standing "late arrivals" issue to point at,
and #19 closes with this change — a deferral linked there would land on a closed issue.

The counter is run-local, and **the re-fetch above must not reset it.** Stage 1 writes
`stage5_reentries` only when it creates the ledger; re-running its fetch against a ledger
that already exists updates items, hashes and watermarks and leaves this field alone.
Without that carve-out the bound erases itself: step 1 sends the run back through section
1, section 1 re-runs the Stage 1 fetch, and a Stage 1 that rewrites the ledger head puts
the counter back to `0` — so step 2 is unreachable and the cycle this section exists to
close stays open.

Recording the counter in the ledger is what keeps a resumed Stage 5 from inventing
whether its one return was already spent.

## 2. Reconcile

Every claim on every ledger item must be one of:

| Status | Requires |
|---|---|
| `fixed` | a commit SHA that exists in `git log` |
| `rebutted` | the evidence that refutes it, quoted |
| `deferred` | a reason **and** an issue link — always, no exceptions |
| `informational` | nothing — it asked for nothing |
| `unresolvable` | **a commit SHA that exists in `git log`**, plus one of the causes below |

`deferred` needs a destination. There are two honest endings for anything you accept
and do not fix: fix it now, or file it where someone will see it. "Noted it" is not a
third ending — a silent deferral costs the fix entirely, and an issue costs one
paragraph.

**An accepted fix that you attempted and could not complete is `deferred`.** The linked
issue records what you tried and why it failed. It is not `rebutted`, because the claim is
still true, and not `unresolvable`, which requires a fix commit that already exists.

**Too minor to file is too minor to defer.** A real finding that does not warrant an
issue is not stuck between the two endings — it takes the first one at a lower
severity: post it as `Nit:` or `FYI:` in the summary, under section 7's cap, and close
the claim as `rebutted` citing the post. It has been said where the author will read
it, which is all a trivial issue would have achieved. What is banned is the finding
that goes nowhere at all, not the finding too small for a tracker. If it does not
survive the 5-finding cap either, it was not worth raising and Filter 2 should have
killed it.

**Fold into an existing issue before opening one.** List the open set and match on
surface — same file, same feature, same error — not on similar titles, which drift.
This matters most when several agents review in parallel: each sees only its own work,
so without reading the open set first they file colliding issues on one file. That
happened here — seven agents filed the same finding seven times.

Reconcile **claims**, not items. An item with nine closed claims and one open is an
open item, and its comment gets one reply covering all ten — never one reply implying
the whole comment is handled.

**A claim still `open` means this stage is not done.** Go back to Stage 4 or record a
deferral. Do not proceed with an open item and a summary that implies completeness.

`unresolvable` is `fixed` that cannot close its thread. It carries **every requirement
`fixed` carries** — a commit SHA verified against `git log` — plus exactly one of two
causes. **This is where they are defined; everywhere else refers here**, because they have
been restated in three places and a third cause would have had to find all three.

1. **`surface` is `inline` and `thread_id` is `null`** — pagination dropped the thread, or
   its first comment was deleted.
2. **A reply or resolve that errored**, per section 6. Any surface can hit this one.

**A null `thread_id` makes only an `inline` item unresolvable.** A top-level comment, a
review body and the PR description have no thread, so null on any of them is the right
answer rather than a failure, and they close as `fixed`, `deferred` or `informational`
like anything else. Reading null as a failure
on every surface turns ten items of thirteen unresolvable on a real PR and posts a warning
about threads that never existed.

A missing thread ID is not permission to skip the fix. An item with no commit is
`open`, or `deferred` with a reason; it is never `unresolvable`. The status describes
a reporting limitation, not a lighter bar.

Then **say so in the summary**, in the line section 7 owns — it names which of the causes
applies, and a copy here would go on saying "thread ID missing" after a 403. Never let it
read as complete. Never invent a thread ID.

Verify `fixed` claims against `git log`, not against your own memory of having made
the edit. The commit must exist.

### Our own findings

The `findings` array reconciles too, and nothing in it stays `open` either. `intake.md`
owns the five endings and what each means; a second definition here would drift from it,
exactly as the item schema did. What belongs to Stage 5 is the evidence bar: `fixed`
needs a commit SHA that exists in `git log`, `deferred` needs a reason and an issue link,
`rebutted` needs the evidence quoted. `posted` and `dropped` need the decision below.

**All five settle here, including `posted` and `dropped`.** What the summary carries is
computable before it is written — severity, the five-finding cap, and whether anything
blocks — so decide it in this section and let section 7 post exactly what is marked
`posted`. Settling them at section 7 puts them after section 5's counters, which read
`status`: every run that posted a finding would then count it open and red a clean head.

`dropped` is the ending the author never reads, so it is the one that has to record why.
Three causes, all legitimate:

- **The cap.** Section 7's "plus N similar" line is the count; a `dropped` finding
  missing from it has vanished.
- **Silence.** The final checklist permits silence only when the remaining findings are
  `NIT`/`FYI` and no ledger item needed a reply. Those low-severity findings are dropped,
  not forgotten.
- **Dedupe.** `verification.md` finds a candidate — a reviewer item by `path` and line, a
  finding from an earlier run by `site_key` — then verifies it is the same defect before
  suppression. Record the item or site key it merged into.

A `BLOCKER` is never `dropped`: the cap is on non-blocking findings, silence requires
that nothing blocking survived, and dedupe never suppresses a blocker.

### Coverage evidence

Read the ledger's run-local `coverage` array before deciding what to say. Session output
always includes the full `checked` value for every `clean` and `cleared` object; this is
the substantive evidence that a lens looked and found the changed surface sound. Also
name `not-dispatched` and dead lenses under their existing rules. Do not turn coverage
objects into findings or give them finding statuses.

When a summary is posted for any reason, include one compact coverage line naming the
clean and cleared lenses, for example:

```
Coverage: clean — money, security, tenancy; cleared — red-team (7 checks).
```

This line does not break silence by itself. A clean review may still post nothing; its
full coverage remains in the session output.

**It degrades to counts, and counts have a fixed cost.** Naming the lenses is already the
compressed form, and it is not bounded: eighteen lenses that answer clean is a roster of
roughly 270 characters against a budget this file calls nearly exhausted. When the budget
binds, drop the names and post the counts alone —

```
Coverage: 15 clean, 1 cleared, 2 not-dispatched.
```

— which costs the same on every run whatever the lenses did. That form is never removed
from a summary that is already being posted. The named form is a courtesy the budget
grants when it can afford it, not a floor.

**Stamp `reconciled_at_head` when reconciliation finishes**: `git rev-parse HEAD`, never
`$HEAD_SHA`. Stage 0 bound that before Stage 4 committed anything, so the two fields
together record how far the head moved under the review.

**Say it when the two differ**, in the summary's verdict line: the head moved while the
review ran and the verdict is against the later one. The ledger holding both is
gitignored and dies with the run, so a field nobody ever reads out loud is a field that
did not survive to be read.

## 3. Re-check eligibility

Before writing anything public:

```bash
gh pr view "$PR" --json state,mergedAt,baseRefName
```

Stop if closed, merged, or the base branch changed — changed against the ledger's
`base`, which Stage 0 bound and the diff was taken against. Posting a review into a
merged PR is pure noise and it happened in the record.

## 4. Refuse to report success

The gate is the agent's own refusal, not a repository setting. **Do not report a clean
result while a ledger item is open or a `BLOCKER` is still unfixed.** A blocker that
survived Stage 3 and was fixed in Stage 4 is not outstanding — what blocks is what is
unfixed now, not what the gate saw. Say what is outstanding, in the session output and
in the summary comment, and exit non-zero if the host gives you an exit code.

That is the only enforcement this skill can carry, because it is the only one that
works in a repository it knows nothing about. Assume no CI, no bot, no branch
protection, no permission to change repository settings, and no maintainer who has
configured anything.

Posting a commit status is optional and repo-dependent, and it belongs **after** the
push. It is in section 5.

## 5. Push

```bash
git status --porcelain   # must be empty — Stage 4 commits as it goes
git push origin HEAD
```

A non-empty tree here is a Stage 4 bug. Do not "fix" it with a catch-all commit —
find the fix that did not commit and commit it with its finding cited.

### Then the commit status, if the repo wants one

**Optional, for repos that want it binding.** Where the token can write statuses, post
one and let the repo decide whether to require it. **Post it on both paths** — a
context that only ever goes red can never clear, and a maintainer who then requires it
has blocked every clean head:

```bash
LEDGER_UNREADABLE=

OPEN_CLAIMS=$(python3 -c 'import json,sys
led = json.load(open(sys.argv[1]))
closed_claim   = {"fixed", "rebutted", "deferred", "informational", "unresolvable"}
closed_finding = {"fixed", "posted", "deferred", "rebutted", "dropped"}
print(sum(1 for i in led["items"] for c in i["claims"] if c["status"] not in closed_claim)
    + sum(1 for f in led.get("findings", []) if f.get("status") not in closed_finding))' "$LEDGER") \
  || LEDGER_UNREADABLE=1

BLOCKERS=$(python3 -c 'import json,sys
led = json.load(open(sys.argv[1]))
print(sum(1 for i in led["items"] for c in i["claims"]
          if c.get("severity") == "BLOCKER"
          and c.get("status") not in {"fixed", "rebutted", "unresolvable"})
    + sum(1 for f in led.get("findings", [])
          if f.get("severity") == "BLOCKER"
          and f.get("status") not in {"fixed", "rebutted"}))' "$LEDGER") \
  || LEDGER_UNREADABLE=1

if [ -n "$LEDGER_UNREADABLE" ]; then
  echo "review-agent: $LEDGER missing or unreadable — no status posted" >&2
else
  if [ "$OPEN_CLAIMS" -eq 0 ] && [ "$BLOCKERS" -eq 0 ]; then STATE=success; else STATE=failure; fi
  gh api "repos/$REPO/statuses/$(git rev-parse HEAD)" \
    -f state="$STATE" -f context="review-agent" \
    -f description="$OPEN_CLAIMS open, $BLOCKERS blocking"
fi
```

**Recompute the SHA here; never reuse `$HEAD_SHA`.** Stage 0 binds it before Stage 4
has made a single fix commit, so by the time this runs it names a commit that is no
longer the PR's head. GitHub attaches a status to one commit and nothing carries it
forward, so a status on the stale SHA is invisible on the PR. Posting before the push
has the same defect plus one more: the commit it names is not on the remote yet.

**Both counts come from the ledger, never from memory.** `$OPEN_CLAIMS` is every claim
whose status is not one of the five section 2 accepts — **claims, because that is where
status lives**; an item carries none, and `i["status"]` raises `KeyError` on every
ledger `intake.md` describes — plus every finding of ours still open. `$BLOCKERS` is
derived from both arrays: reviewer claims and findings carrying `BLOCKER`, with their
schema-defined fixed endings excluded. Nothing decrements it, so it cannot disagree with
the statuses it is computed from.

`closed_finding` is `intake.md`'s five endings, spelled out because bash cannot read a
table. Add a sixth status there and not here and every finding carrying it counts as
open, which reds a clean head — the one place the two-copies rule could not be avoided,
so it is the one place to check when a status is added.

**Both read the ledger with `.get`, never `[]`.** A ledger written before `findings`
existed, or by a run that stopped early, raises `KeyError` on a subscript; the counter
captures empty, `[ "" -eq 0 ]` is a bash error, and the `else` branch posts `failure` on
a head with nothing left wrong. A missing array is zero findings, which is the honest
reading and the one that keeps the status truthful.

Compute both after Stage 4, never before — the count that survived the gate is not the
count still open, and posting the first one reds a head where every blocker is already
fixed. Section 7's silence checklist is a separate question: a blocker found and fixed
still gets said out loud. An unassigned counter makes
`[ "$OPEN_CLAIMS" -eq 0 ]` an error, and the `else` branch posts `failure` on a clean
head — the exact defect this section exists to prevent.

`success` needs both at zero — exactly the condition section 4 refuses to report
success without, so the status cannot disagree with the summary.

Section 7's silence does not reach this. A status is not a comment: a clean review
posts `success` here and still posts no summary comment.

**If the ledger is missing or will not parse, post no status at all.** Say so in the
session output. `success` is barred by section 4 on a ledger you cannot read, and
`failure` is a guess about a head you know nothing about — the `else` branch would post it
on every run whose ledger went missing, including clean ones. A context that is absent is
a maintainer's question; a context that is wrong is one they act on.

**Skip the status, not the rest of the stage.** Sections 6 and 7 still run from the
reconciliation you did in section 2, and the non-zero exit comes at the end of Stage 5.
Exiting here would be the abort section 6 forbids, in a block this file calls optional:
the fixes are already pushed, so the run would leave commits on the PR with no reply, no
marker and no summary — and the next run, finding no markers, would cold-start and do all
of it again.

This is the one place `gh`'s counterpart rule does not transfer: a malformed *history*
file is skipped line by line and the run continues, because history is an optimisation.
The ledger is the artifact this stage exists to reconcile, so an unreadable one means
Stage 5 has nothing to say and has to say that.

Treat a permission error as expected, not as a failure — many tokens cannot write
statuses, and the review is still valid without one. Never instruct anyone to turn on
branch protection as part of a review: that is a maintainer's decision about their own
repository, and a required check that nothing reliably posts blocks every merge.

## 6. Reply in threads

Inline findings get inline replies **on their own thread**, never as a top-level
comment:

**Never interpolate a body into a shell command.** Build the JSON in `python3` and pipe
it in. Replies quote code, so they carry backticks, and `-f body="$REPLY"` hands those to
the shell: this file's own review posted three replies whose every quoted term had been
deleted by command substitution, marker intact and sentences gutted.

```bash
python3 -c 'import json,sys; print(json.dumps({"body": sys.stdin.read()}))' < reply.md \
  | gh api "repos/$REPO/pulls/$PR/comments/$COMMENT_ID/replies" --input -
```

To update a comment already posted, same payload with `--method PATCH`. **The endpoint
depends on which kind it is, and the two ID spaces do not overlap:**

| Comment | PATCH |
|---|---|
| an inline reply on a thread | `repos/$REPO/pulls/comments/$REPLY_ID` |
| the summary, and any top-level comment | `repos/$REPO/issues/comments/$COMMENT_ID` |

The summary is an issue comment, not a review comment. Sending its ID to
`pulls/comments` returns 404 — checked against this repo — and the summary is edited on
every run, so getting this wrong breaks the carrier for `top` items, `review` items, the
PR description and every finding, on the second run of every PR.

Reply templates — keep them this short:

- **Fixed:** `Fixed in <sha>. <one line on what changed and why that closes it>.`
- **Rebutted:** `<what the code actually does, with the quoted line>. Not changing this.`
- **Deferred:** `Real, out of scope here — tracked in <issue>.`

Never open with "Thanks", "Good catch", or "You're absolutely right". State the fix.
The commit shows you heard it.

### The marker

**Every reply ends with one marker, in its trailer.** It is the next run's ledger;
`$LEDGER` is gitignored and does not survive. Without it the next run sees a resolved
thread and an unchanged hash and still cannot tell what was decided, so it re-opens the
item and does the work again.

```html
<!-- review-agent: {"item":3640790504,"substance":"sha256:9f2a...","claims":{"1":{"status":"fixed","sha":"abc123f"},"2":{"status":"deferred","issue":42}}} -->
```

**JSON, and only constrained values** — ids, hex, status words, issue numbers. No prose,
ever. The delimited form this replaced (`claims=1:fixed:abc,2:rebutted`) broke on the
first resolution containing a comma or a colon, which a deferral's issue URL always does.
Evidence and reasons live in the reply text, where a human reads them; the marker carries
only what the next run has to parse.

**In the trailer, because position is half the trust rule.** `intake.md` reads a marker
only from a `SELF` comment where every line after it is another marker or blank, and no
line of it is `>`-quoted. Put markers at the very bottom, after the last visible line,
with nothing under them. A reply carries one; the summary carries many.

**Edit the existing reply; never post a second one.** A thread carries exactly one
marker-bearing reply of ours, updated in place, so there is no accumulation and no
tiebreak to get wrong.

**Reply only when something moved** — the claim's status, or the item's `substance_hash`,
since the marker already on that thread. A rebuttal and a deferral are never resolved, by
the rule below, so their threads stay open forever: without this test an hourly fleet
posts an identical reply to each of them every hour, against a shared secondary rate
limit, and every run afterwards pages the grown comment set back in.

### Resolve threads

Resolve a thread when its fix commit exists **and** `thread_id` is not null. Skip the
mutation entirely when it is null — calling it with an empty argument errors. On an
`inline` item that null is the `unresolvable` case and is already accounted for; on a
`top`, `review` or `description` item there is no thread to resolve and nothing is owed.

```bash
gh api graphql -f query='
  mutation($id:ID!) {
    resolveReviewThread(input:{threadId:$id}) { thread { isResolved } }
  }' -f id="$THREAD_ID"
```

**Never auto-resolve a rebuttal or a deferral.** Those stay open for a human. Replying
is not resolving; resolving is the claim that the work is done.

### When the reply or the resolve fails

**Check the exit code.** Then read it, because these failures need different answers and
treating them alike gets each one wrong.

**403 — the token cannot write. Stop the posting pass.** Report "no write access" once
and exit non-zero. Do not mark N claims `unresolvable`: that status tells a human to close
threads by hand, and no human can act on a permission this run never had. It is also
unclosable by definition — the summary that would report those N claims is a write too,
and it 403s as well. Section 5 already treats the same error on the commit status as
expected rather than a failure.

**Probe that permission in section 3, before Stage 2 runs.** A token that cannot write is
a property of the run, not a surprise at the last step, and discovering it after eighteen
lenses means the fleet pays for a full review every hour and dies at the same call with
nothing recorded. Treat it as an ineligibility, the way a merged PR is.

**404 — the PR moved. Re-run section 3's eligibility check.** If it is closed or merged,
stop the posting pass and say so. A maintainer merging at thread 2 of 12 otherwise costs
ten more failed writes and a summary telling them to hand-close ten threads on a merged
PR, which is the noise section 3 exists to stop.

**A secondary rate limit or a 429 — slow down, do not work harder.** Honour `Retry-After`
before the next call, and stop the posting pass after three consecutive failures: mark the
remaining claims `delivery: "failed"` and report them under section 7's second line.
Treating throttling as a per-thread problem answers it with *more* requests — the
landed-write check below adds a read per failure — while GitHub is asking for fewer, and
the budget is shared with every other run in the fleet.

**Anything else — one thread's problem. Carry on with the others.** A deleted thread, a
transient 5xx.

For that last case only:

- **Never abort.** The fixes are committed and pushed. A run that dies here throws away a
  completed review because it could not announce it, which is strictly worse than
  announcing it badly.
- **Check whether the write actually landed before you report it as failed.** A reply POST
  is not idempotent, and "created, then the response was lost" is a real 502. Re-fetch that
  thread and read our marker. **Match its payload against what this attempt meant to
  write** — the claim statuses and the `substance` — because a thread that already carried
  a marker from an earlier run will always have one, and presence alone would read a stale
  `deferred` as proof that this run's `fixed` landed. A matching payload means the write
  landed and only the resolve is outstanding; anything else is a confirmed-absent reply.
- **A `fixed` claim whose reply or resolve is confirmed missing becomes `unresolvable`.**
  That status already means "fixed, and we cannot close the loop on GitHub", so it now has
  section 2's second cause, and it lands in section 7's line even on an otherwise silent
  run.
- **A `rebutted`, `deferred` or `informational` claim keeps its status.** `unresolvable`
  requires a commit SHA and section 2 bars it without one. Those claims are correctly
  decided; what failed is telling the author.

**Record the failure on the claim, not in the status.** On any claim whose reply or
resolve errored, whatever its status, set:

```json
"delivery": {"call": "resolve", "code": 502, "url": "https://github.com/..."}
```

Status says what we decided; `delivery` says whether the author was told, and the two are
independent. **Which call, and its code** — a failed reply means the thread never got the
answer, a failed resolve means it got the answer and stayed open. Reporting both as
"decided but not answered" sends the maintainer to re-read a thread that already carries
its reply, and the next run cannot tell that the non-idempotent reply already succeeded.

Routing this through `unresolvable` alone loses exactly the claims that cannot take it.
Four inline comments, two rebutted and two deferred, every reply erroring: each claim
keeps a status section 5 counts as closed, no claim is `unresolvable`, so the status posts
`success`, section 7 stays silent, and four reviewer comments got no answer on a PR that
reads as handled. That is what `unresolvable` was invented to prevent, reached by the
other door.

If the summary comment itself cannot be posted, apply the same landed-write check — it is
the same non-idempotent create — and re-fetch the PR's comments for our marker before
calling it failed. Only when it is confirmed absent: say so in the session output and exit
non-zero. There is nowhere left to write it down, and a review nobody can see must not
report itself as delivered. Declaring it failed when it landed is worse still: the next
run finds the summary, and pays for a whole review to discover it was already delivered.

**A thread already resolved on arrival is not evidence its claim is closed.** Anyone
can resolve a thread — including a previous run that closed it by proxy. Reconcile the
claim on its own merits and, when it turns out to be open, say so in the reply rather
than leaving a resolved thread standing over unfinished work. This repo had one:
resolved on arrival, claim closed two commits later by this run.

## 7. The summary — or silence

**Decide once, with the silence checklist at the end of this file.** Do not derive a
second decision from blocker and ledger counts here. The rest of this section defines
what a required summary contains; a clean PR still does not need an announcement.

**Four delivery and coverage failures require their own summary line.** In each case,
silence would be a lie.

**An unreadable ledger.** Section 5 skips the status when it cannot read the ledger, and
sections 6 and 7 then run with nothing to announce — so the PR ends up carrying no
context and no comment, which is byte-for-byte what a clean review leaves behind. One
line, because the session output is not a place anyone is watching:

```
Ledger unreadable — nothing in this run was reconciled. Re-run before trusting it.
```

**A dead lens.** Stage 2 requires naming a lens that did not answer, and silence would
delete exactly that. A run reporting a clean review while an always-on lens died reports
coverage it does not have — and at fleet cadence nobody is watching the session output,
so the summary is the only place it can land. One line, and it does not block:

```
No answer from: coherence. That lens's coverage is missing from this review.
```

Not-dispatched reasons are a different thing: they are a lens correctly declining, not a
lens failing, so they do not break silence. Name every reason in the session output. When
another exception causes a summary, include them there in one compact coverage line too.

**An `unresolvable` item.** Silence means "nothing needs your attention", and an
`unresolvable` item leaves a thread open that nobody will close. If any item carries
that status, post — even when nothing blocks and everything else is clean. One line is
enough:

```
N item(s) fixed but not resolvable — thread ID missing: <urls>. Close them by hand.
N reply/resolve call(s) failed, so these were decided but not answered: <urls>.
```

**One line per cause, never one line for all of them.** The remediation differs — a
missing thread ID is information that is gone, an errored call is something to retry — and
a single label over a mixed set sends the maintainer to check the wrong thing. The second
line is not "fixed but not resolvable": the claims on it may be rebuttals or deferrals,
and calling those fixed would be worse than saying nothing.

**A failed delivery.** Any claim carrying `delivery: "failed"` needs the line for its
failure cause. The decision is sound and the author never heard it, so silence would
report a conversation that did not happen.

Silence here would be a lie of exactly the kind the ledger exists to prevent: the
work is done, the PR still looks unaddressed, and nothing says why.

Otherwise, one top-level comment. Hard caps:

- **2,000 characters.** Not a target — a limit. **When it binds, cut in this order:**
  the coverage line's detail — the not-dispatched reasons first, then the clean, cleared
  and not-dispatched lens names — leaving its counts; then non-blocking findings, down to
  the count line; then prose. Never delete the coverage line, the markers, or the three
  lines silence cannot suppress — a dead lens, `unresolvable` items, failed deliveries.
  Those are the summary's whole reason for existing on a run that would otherwise be
  quiet. The mandatory lines added here spend budget that issue #23 already measured as
  nearly exhausted, so which line gives has to be written down rather than decided in the
  moment.

  **Compress before deleting, so coverage gives before findings do.** Degrading the
  coverage line loses detail; cutting a finding loses the finding. Coverage is also the
  only element here whose cost grows with the number of lenses rather than with what the
  review found, so it is what a wide run should spend first. And cutting a finding to keep
  a lens name mislabels the ledger: that finding is recorded `dropped` with reason `cap`,
  on a run where the 5-finding cap never bound.
- **5 non-blocking findings** maximum. Beyond that: "plus N similar, not listed." Each
  one you leave out is `dropped` in the ledger, and N is that count.
- Every finding carries a severity prefix and a `file:line`.
- Every finding carries an invisible marker so it can be found again later:
  `<!-- review-agent: {"fingerprint":"<f>","site_key":"<path:anchor>","specialist":"money","category":"money","categories":["correctness","money"],"corroborated_by":["correctness","money"],"score":68,"gate_reason":"corroboration","severity":"REQUIRED","status":"posted"} -->`.
  `severity` and `status` are not optional — section 5's counters read exactly those two
  fields off every finding, and a rebuilt finding missing them counts as neither open nor
  closed. `score` is always raw, never raised to encode corroboration. Without the
  marker, category and convergence are unrecoverable from a posted comment and
  calibration is impossible. Older markers without the additive fields remain valid;
  `intake.md` defines their normalization.
- **A status with a destination carries it.** `"status":"deferred","issue":42` and
  `"status":"dropped","why":"cap"` — one of `cap`, `silence`, `dedupe`. `posted` and
  `rebutted` need nothing more: the reason is the visible text beside the marker. A
  status restored without its destination is a status nothing can act on — a deferral
  whose issue is unrecoverable reads as handled and points nowhere.

### The summary is one comment per PR, edited in place

Post it once and **edit that same comment on later runs**. It is the carrier for
everything without a thread: `top` items, `review` items, the PR description, and every
finding whose ending `git` cannot show. Each gets one marker, in the trailer.

**A `fixed` finding is recovered from `git log`, not from a marker.** Stage 4 writes
`Finding: <specialist>/<fingerprint>` into the commit that fixes it, so
`git log --fixed-strings --grep="<fingerprint>"` on the current branch answers both questions
at once: whether we fixed it, and whether the fix is still here. A force-push or a dropped
rebase takes the commit and the grep result together, and the finding re-opens.

That is the ancestry check the claim side does by hand, for free and with no SHA to keep
in sync — which is why the marker has no resolution field for `fixed`. Putting one there
would be a second copy of something `git log` already holds, and the copy is the half that
goes stale.

An inline comment has a thread to reply in. The other three surfaces have none, so a
second top-level comment per run is the only alternative, and that is the noise the
2,000-character cap exists to stop. Bots in this record already work this way — one
summary, edited on each run — which is why intake watermarks on `updated_at`.

**When silence suppresses the summary and no prior one exists, nothing carries.** Those
items re-verify on the next run at the cost of one verification pass. That is the price
of not announcing a clean review, and it is the right way round: a wasted pass, never a
wrong answer.

### Shape

```
<verdict in one line: what is blocking, or that nothing is>

Blocker: <file:line> — <problem>. <fix>.
Required: <file:line> — <problem>. <fix>.

Coverage: clean — money, security, tenancy; cleared — red-team (7 checks).
Reviewer items: N fixed, N rebutted, N deferred.
```

Line one is the verdict. Not what you did, not what is coming, not how many agents
ran. Findings ordered by severity, not by discovery order.

---

## Writing

`../CONTRIBUTING.md` sets the bar; it applies to posted comments too. The three that
bite hardest here:

- **No preamble.** No "Let me", no "I'll now", no "Analysis complete". Line one is the
  verdict.
- **Say each fact once.** No recap, no closing offer of help.
- **One structural problem and ten nits means the structural problem *is* the review.**
  Post it alone.

## The silence checklist

Post nothing when **all** of these hold:

- No reviewer claim or finding remains `BLOCKER` under section 5's derived count.
- No claim is `unresolvable`.
- No claim carries a `delivery` failure.
- No lens was classified as dead.
- The ledger parsed.
- Everything found is in `exclusions.md`, **or** the only findings are `NIT`/`FYI`
  and no ledger item needed a reply.
- A prior review by us exists at this head SHA and nothing re-opened.

Every condition is required. An unfixed blocker, an `unresolvable` item, an undelivered
claim, a dead lens or an unreadable ledger posts regardless of what the others say — each
is a case where silence states something untrue.

Say what you did in the session output instead. The PR is not a log.
