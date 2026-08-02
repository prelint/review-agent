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
- Changed `body_hash` on any existing item → it re-opens, even if it was `fixed`.
- Changed PR description hash → re-run `spec-drift` before continuing.

## 2. Reconcile

Every ledger item must be one of:

| Status | Requires |
|---|---|
| `fixed` | a commit SHA that exists in `git log` |
| `rebutted` | the evidence that refutes it, quoted |
| `deferred` | a reason, and an issue link if it is real work |
| `informational` | nothing — it asked for nothing |
| `unresolvable` | a `thread_id` of `null` from intake. The fix may exist; the thread cannot be closed. |

**An item still `open` means this stage is not done.** Go back to Stage 4 or record a
deferral. Do not proceed with an open item and a summary that implies completeness.

`unresolvable` is the one status that closes the ledger without closing the thread.
It is reserved for an intake join failure — a `thread_id` of `null`, meaning
pagination dropped the thread or its first comment was deleted. Fix the finding and
commit as normal, then **say so in the summary**: `N item(s) fixed but not resolvable
— thread ID missing.` Never let it read as complete. Never invent a thread ID.

Verify `fixed` claims against `git log`, not against your own memory of having made
the edit. The commit must exist.

## 3. Re-check eligibility

Before writing anything public:

```bash
gh pr view "$PR" --json state,merged,baseRefName,isDraft
```

Stop if closed, merged, or the base branch changed. Posting a review into a merged PR
is pure noise and it happened in the record.

## 4. Push

```bash
git status --porcelain   # must be empty — Stage 4 commits as it goes
git push origin HEAD
```

A non-empty tree here is a Stage 4 bug. Do not "fix" it with a catch-all commit —
find the fix that did not commit and commit it with its finding cited.

## 5. Reply in threads

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

## 6. The summary — or silence

**If nothing blocking survived Stage 3 and every ledger item is closed, post nothing.**
Push the fixes and stop. A clean PR does not need an announcement, and the record's
worst comment was 10 KB reporting "0 blocking, 6 informational".

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

Post nothing when:

- Everything found is in `exclusions.md`.
- The only findings are `Nit:` or `FYI:` and no ledger item needed a reply.
- A prior review by us exists at this head SHA and nothing re-opened.

Say what you did in the session output instead. The PR is not a log.
