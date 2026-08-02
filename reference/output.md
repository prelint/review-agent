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

Every ledger item must be one of:

| Status | Requires |
|---|---|
| `fixed` | a commit SHA that exists in `git log` |
| `rebutted` | the evidence that refutes it, quoted |
| `deferred` | a reason, and an issue link if it is real work |
| `informational` | nothing — it asked for nothing |
| `unresolvable` | **a commit SHA that exists in `git log`**, plus a `thread_id` of `null` from intake |

**An item still `open` means this stage is not done.** Go back to Stage 4 or record a
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

## 3. Re-check eligibility

Before writing anything public:

```bash
gh pr view "$PR" --json state,merged,baseRefName,isDraft
```

Stop if closed, merged, or the base branch changed. Posting a review into a merged PR
is pure noise and it happened in the record.

## 4. Refuse to report success

The gate is the agent's own refusal, not a repository setting. **Do not report a clean
result while a ledger item is open or a `Blocker:` survived Stage 3.** Say what is
outstanding, in the session output and in the summary comment, and exit non-zero if the
host gives you an exit code.

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
if [ "$OPEN_ITEMS" -eq 0 ] && [ "$BLOCKERS" -eq 0 ]; then STATE=success; else STATE=failure; fi

gh api "repos/$REPO/statuses/$(git rev-parse HEAD)" \
  -f state="$STATE" -f context="review-agent" \
  -f description="$OPEN_ITEMS open, $BLOCKERS blocking"
```

**Recompute the SHA here; never reuse `$HEAD_SHA`.** Stage 0 binds it before Stage 4
has made a single fix commit, so by the time this runs it names a commit that is no
longer the PR's head. GitHub attaches a status to one commit and nothing carries it
forward, so a status on the stale SHA is invisible on the PR. Posting before the push
has the same defect plus one more: the commit it names is not on the remote yet.

`$OPEN_ITEMS` counts ledger items that are not `fixed`, `rebutted`, `deferred`,
`informational` or `unresolvable`. `$BLOCKERS` counts `Blocker:` findings surviving
Stage 3. `success` needs both at zero — exactly the condition section 4 refuses to
report success without, so the status cannot disagree with the summary.

Section 7's silence does not reach this. A status is not a comment: a clean review
posts `success` here and still posts no summary comment.

Treat a permission error as expected, not as a failure — many tokens cannot write
statuses, and the review is still valid without one. Never instruct anyone to turn on
branch protection as part of a review: that is a maintainer's decision about their own
repository, and a required check that nothing reliably posts blocks every merge.

## 6. Reply in threads

Inline findings get inline replies **on their own thread**, never as a top-level
comment:

```bash
gh api "repos/$REPO/pulls/$PR/comments/$COMMENT_ID/replies" -f body="$REPLY"
```

Reply templates — keep them this short:

- **Fixed:** `Fixed in <sha>. <one line on what changed and why that closes it>.`
- **Rebutted:** `<what the code actually does, with the quoted line>. Not changing this.`
- **Deferred:** `Real, out of scope here — tracked in <issue>.`

Never open with "Thanks", "Good catch", or "You're absolutely right". State the fix.
The commit shows you heard it.

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
- **5 non-blocking findings** maximum. Beyond that: "plus N similar, not listed."
- Every finding carries a severity prefix and a `file:line`.
- Every finding carries an invisible marker so it can be found again later:
  `<!-- review-agent: category=<c> fingerprint=<f> score=<n> -->`. Without it,
  category is unrecoverable from a posted comment and calibration is impossible.

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

- No ledger item is `unresolvable`.
- Everything found is in `exclusions.md`, **or** the only findings are `Nit:`/`FYI:`
  and no ledger item needed a reply.
- A prior review by us exists at this head SHA and nothing re-opened.

The first condition is a gate, not one option among three. An `unresolvable` item
posts regardless of what the other two say.

Say what you did in the session output instead. The PR is not a log.
