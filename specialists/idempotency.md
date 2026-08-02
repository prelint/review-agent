# Specialist: idempotency

Read `_schema.md` first.

**Runs when** the diff touches webhook handlers, event consumers, queue workers, cron
jobs, retry logic, or anything that can run twice.

**Why this exists:** every delivery guarantee available here is at-least-once.
Duplicate GitHub reviews from concurrent finalizers, duplicate Sentry references,
member-removal webhooks racing each other — all in the record, all the same shape,
none owned by an existing lens.

**Severity floor:** a duplicate that is customer-visible or costs money is `BLOCKER`.

---

## Check

**Assume every handler runs twice, concurrently.** Not "could a retry happen" — it
will. Providers redeliver on timeout, on 5xx, and sometimes on success. Two workers
will pick up the same event. Write the finding against that assumption.

**The dedup key is stable and stored before the side effect.** A key derived at
handling time (`uuid4()`, `now()`) deduplicates nothing. The key must come from the
event (delivery ID, event ID, commit SHA, run ID) and must be persisted with a unique
constraint **before** the effect fires, not after.

**Check-then-act is not atomic.** `if not exists(...): create(...)` between two
workers creates two. Look for the unique constraint, the `select_for_update`, the
advisory lock, or the `get_or_create` that makes it one operation. A comment saying
"should be safe" is not a mechanism.

**The guard covers the whole effect, not the first step.** A handler that dedupes its
database write but then posts to GitHub outside the guarded block posts twice. Trace
every external call and every non-transactional side effect inside the handler.

**Ordering is not guaranteed.** Events arrive out of order. A handler that applies
"member removed" before "member added" must be safe, or must carry a sequence or
version and reject stale ones. Check what happens when the older event arrives last.

**Late events after state moved on.** A webhook for a superseded run, a cancelled
subscription, a deleted object. Does the handler no-op cleanly, or does it resurrect
dead state? Look for an explicit staleness check against the current head or version.

**Partial failure is recoverable.** If step 3 of 5 fails, does a retry redo 1 and 2
safely? A handler that is idempotent as a whole but not per-step will corrupt on
retry.

**Poison messages have an exit.** An event that always fails must eventually stop —
a retry cap, a dead-letter queue, an alert. Infinite retry is an outage with extra
cost.

**Locks have owners and expiry.** A lease based only on heartbeat age lets a new
holder proceed while the old process is still writing. Fencing tokens, or a check the
original process makes before its own writes, or the lock is advisory only. Quote the
window.

**Transaction boundaries.** An external call inside a transaction that later rolls
back has already happened. A `transaction.on_commit` that was dropped, or a provider
call before `commit`, is a divergence between what the database believes and what the
world did.

---

## Not a finding

- Read-only handlers with no side effects.
- Retries where duplication is genuinely harmless and you can say why.
- Theoretical interleavings you cannot name a schedule for. State the schedule or
  drop it.

## Evidence bar

Quote the handler entry point, the dedup key's derivation, and the side effect. For a
race, name the interleaving: "worker A passes the `exists` check at T1, worker B
passes at T1, both insert at T2".

"This may not be idempotent" is not a finding. "A redelivered `pull_request.synchronize`
posts a second inline review because the guard at services.py:214 commits after the
`gh` call at :231" is.
