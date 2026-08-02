# Stage 5: Close and post

Nothing is posted until the ledger reconciles. That is the whole point of this stage.

The failure it replaces: thirteen times in two weeks the founder pasted a reviewer
comment back into a session and asked whether it had been handled. There was no
artifact that could answer.

---

## 1. Re-fetch

Re-run the Stage 1 fetch. All of Stage 2–4 took time; the PR moved.

- New comments since Stage 1 → new ledger items. Process them, or record them
  `deferred` with a reason and say so in the summary. Silently ignoring them is how
  the loop stayed open.
- Changed `substance_hash` on any existing item → it re-opens, even if it was `fixed`.
  A `body_hash` that moved alone is a typo or a reformat: store it and leave the item
  closed. The full table is in `intake.md`.
- Changed `pr_substance_hash` → re-run `spec-drift` before continuing.

## 2. Reconcile

Every claim on every ledger item must be one of:

| Status | Requires |
|---|---|
| `fixed` | a commit SHA that exists in `git log` |
| `rebutted` | the evidence that refutes it, quoted |
| `deferred` | a reason **and** an issue link — always, no exceptions |
| `informational` | nothing — it asked for nothing |
| `unresolvable` | **a commit SHA that exists in `git log`**, plus a `thread_id` of `null` from intake |

`deferred` needs a destination. There are two honest endings for anything you accept
and do not fix: fix it now, or file it where someone will see it. "Noted it" is not a
third ending — a silent deferral costs the fix entirely, and an issue costs one
paragraph.

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
`fixed` carries** — a commit SHA verified against `git log` — plus one more: a
`thread_id` of `null`, because pagination dropped the thread or its first comment was
deleted.

A missing thread ID is not permission to skip the fix. An item with no commit is
`open`, or `deferred` with a reason; it is never `unresolvable`. The status describes
a reporting limitation, not a lighter bar.

Then **say so in the summary**: `N item(s) fixed but not resolvable — thread ID
missing.` Never let it read as complete. Never invent a thread ID.

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
- **Silence.** Section 7 posts nothing when nothing blocks and every item is closed, so
  an unfixed `Required:` is dropped by it too — not only nits. Silence is a decision not
  to spend the author's attention, never a decision to forget.
- **Dedupe.** `verification.md` suppresses a finding matching a reviewer's ledger item or
  one we posted on an earlier run. Record which it merged into.

A `BLOCKER` is never `dropped`: the cap is on non-blocking findings, silence requires
that nothing blocking survived, and dedupe never suppresses a blocker.

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
gh pr view "$PR" --json state,mergedAt,baseRefName,isDraft
```

Stop if closed, merged, or the base branch changed — changed against the ledger's
`base`, which Stage 0 bound and the diff was taken against. Posting a review into a
merged PR is pure noise and it happened in the record.

## 4. Refuse to report success

The gate is the agent's own refusal, not a repository setting. **Do not report a clean
result while a ledger item is open or a `Blocker:` is still unfixed.** A blocker that
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
OPEN_CLAIMS=$(python3 -c 'import json,sys
led = json.load(open(sys.argv[1]))
closed_claim   = {"fixed", "rebutted", "deferred", "informational", "unresolvable"}
closed_finding = {"fixed", "posted", "deferred", "rebutted", "dropped"}
print(sum(1 for i in led["items"] for c in i["claims"] if c["status"] not in closed_claim)
    + sum(1 for f in led.get("findings", []) if f.get("status") not in closed_finding))' "$LEDGER")

BLOCKERS=$(python3 -c 'import json,sys
print(sum(1 for f in json.load(open(sys.argv[1])).get("findings", [])
          if f.get("severity") == "BLOCKER" and f.get("status") not in {"fixed", "rebutted"}))' "$LEDGER")

if [ "$OPEN_CLAIMS" -eq 0 ] && [ "$BLOCKERS" -eq 0 ]; then STATE=success; else STATE=failure; fi

gh api "repos/$REPO/statuses/$(git rev-parse HEAD)" \
  -f state="$STATE" -f context="review-agent" \
  -f description="$OPEN_CLAIMS open, $BLOCKERS blocking"
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
derived from that same array: `BLOCKER` findings that are neither `fixed` nor
`rebutted`. Nothing decrements it, so it cannot disagree with the statuses it is
computed from.

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
fixed. Section 7's silence rule is a separate question and keeps its Stage 3 wording: a
blocker found and fixed still gets said out loud. An unassigned counter makes
`[ "$OPEN_CLAIMS" -eq 0 ]` an error, and the `else` branch posts `failure` on a clean
head — the exact defect this section exists to prevent.

`success` needs both at zero — exactly the condition section 4 refuses to report
success without, so the status cannot disagree with the summary.

Section 7's silence does not reach this. A status is not a comment: a clean review
posts `success` here and still posts no summary comment.

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

To update the reply already on a thread, same payload, `--method PATCH` against
`repos/$REPO/pulls/comments/$REPLY_ID`. The summary comment is edited the same way.

Reply templates — keep them this short:

- **Fixed:** `Fixed in <sha>. <one line on what changed and why that closes it>.`
- **Rebutted:** `<what the code actually does, with the quoted line>. Not changing this.`
- **Deferred:** `Real, out of scope here — tracked in <issue>.`

Never open with "Thanks", "Good catch", or "You're absolutely right". State the fix.
The commit shows you heard it.

### The marker

**Every reply ends with one marker, as its last line.** It is the next run's ledger;
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

**Last line, because position is half the trust rule.** `intake.md` reads a marker only
from a `SELF` comment whose last line it is — a Quote reply copies our body, HTML
comments included, into someone else's words.

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
mutation entirely when it is null — calling it with an empty argument errors and the
item is already accounted for as `unresolvable`.

```bash
gh api graphql -f query='
  mutation($id:ID!) {
    resolveReviewThread(input:{threadId:$id}) { thread { isResolved } }
  }' -f id="$THREAD_ID"
```

**Never auto-resolve a rebuttal or a deferral.** Those stay open for a human. Replying
is not resolving; resolving is the claim that the work is done.

**A thread already resolved on arrival is not evidence its claim is closed.** Anyone
can resolve a thread — including a previous run that closed it by proxy. Reconcile the
claim on its own merits and, when it turns out to be open, say so in the reply rather
than leaving a resolved thread standing over unfinished work. This repo had one:
resolved on arrival, claim closed two commits later by this run.

## 7. The summary — or silence

**If nothing blocking survived Stage 3 and every ledger item is closed, post nothing.**
Push the fixes and stop. A clean PR does not need an announcement, and the record's
worst comment was 10 KB reporting "0 blocking, 6 informational".

**One exception: `unresolvable`.** Silence means "nothing needs your attention", and an
`unresolvable` item leaves a thread open that nobody will close. If any item carries
that status, post — even when nothing blocks and everything else is clean. One line is
enough:

```
N item(s) fixed but not resolvable — thread ID missing: <urls>. Close them by hand.
```

Silence here would be a lie of exactly the kind the ledger exists to prevent: the
work is done, the PR still looks unaddressed, and nothing says why.

Otherwise, one top-level comment. Hard caps:

- **2,000 characters.** Not a target — a limit.
- **5 non-blocking findings** maximum. Beyond that: "plus N similar, not listed." Each
  one you leave out is `dropped` in the ledger, and N is that count.
- Every finding carries a severity prefix and a `file:line`.
- Every finding carries an invisible marker so it can be found again later:
  `<!-- review-agent: {"fingerprint":"<f>","category":"<c>","score":88,"severity":"REQUIRED","status":"posted"} -->`.
  `severity` and `status` are not optional — section 5's counters read exactly those two
  fields off every finding, and a rebuilt finding missing them counts as neither open nor
  closed. Without the marker, category is unrecoverable from a posted comment and
  calibration is impossible.

### The summary is one comment per PR, edited in place

Post it once and **edit that same comment on later runs**. It is the carrier for
everything without a thread: `top` items, `review` items, the PR description, and every
finding. Each gets one marker, below the visible text.

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

## Refusing to post

Post nothing when **all** of these hold:

- No claim is `unresolvable`.
- Everything found is in `exclusions.md`, **or** the only findings are `Nit:`/`FYI:`
  and no ledger item needed a reply.
- A prior review by us exists at this head SHA and nothing re-opened.

The first condition is a gate, not one option among three. An `unresolvable` item
posts regardless of what the other two say.

Say what you did in the session output instead. The PR is not a log.
