# Specialist: performance

Read `_schema.md` first.

**Runs when** the diff touches an ORM query, a serialiser, a list endpoint, a loop
over rows, a migration, a React component, or a data-fetching hook.

**Why this exists:** the taxonomy was never the problem. N+1 and missing pagination
are easy to name and impossible to score — "this could be slow" reads the same whether
it is a 100× regression or noise, so the scorer in Stage 3 has nothing to check.

**Not yours:** `resource-limits` owns the missing ceiling; you own the cost *under*
it. The test is the fix: a cap, a timeout or a page limit is theirs, and anything that
leaves the volume unchanged and makes each unit cheaper is yours. One hunk can be both;
report only your half.

---

## The two numbers

Every finding names both; one without the other is not a finding.

1. **The unit cost.** One query, one render, one serialisation, one round trip. What
   this change adds *per item*.
2. **The multiplier.** How many items, **quoted from this repo** — a default page
   size, a batch constant, a fan-out width, a fixture row count, a `settings` value.

"Adds one query per row, and `list_runs` defaults to `limit=100`" is a finding; "this
is an N+1" is a category; "this could be slow" is an adjective.

**Never invent a number.** An estimate shows its arithmetic and cites both inputs. A
fabricated millisecond is worse than none: it survives Filter 2 by looking like
measurement. Where the multiplier is not in the repo, the band is `unverified` and you
say what you would measure.

## Check

**Queries inside loops.** Quote the loop, the query, and what sizes the loop. A
serialiser resolver is a loop with no `for`, so a resolver that hits the database is an
N+1 with nothing to see. A query whose result does not depend on the loop variable is
the same bug with a cheaper proof. In Django, check the prefetch is still live:
`.filter()`, `.all()` and `.exclude()` on a prefetched relation re-query.

**The new query can reach an index.** Does one exist for the new `WHERE`, `ORDER BY`
or join column — quote the migration or `Meta.indexes`. Then the half reviewers miss:
can the query use it? A function on the column, a leading-wildcard `LIKE`, a type
mismatch on a join key, or an `ORDER BY` on the unindexed twin of an indexed column each
disable an index that is right there. Missing and unreachable indexes are the largest
class of database performance bug in the published record.

**Nothing is built and then dropped.** Columns selected and never read, rows filtered
in Python that the database could filter, a `select_related` pulling a wide table for
one field, an object allocated per row and discarded.

**Round trips are minimised.** N `save()` calls where one `bulk_update` does it.
Sequential `await`s that do not use each other's results. A child query that could
have started alongside its parent.

**Reads use the replica when they can.** Aurora here has a read replica, and a
read-only path pinned to the writer wastes it — quote the router or the `using()`. The
other direction too: a read that follows its own write stays on the writer, because
replica lag returns the pre-write row.

**Async paths stay async.** A blocking call inside `async def` — `requests`, a
subprocess, a file read, `time.sleep` — stalls the event loop, not one request.
`sync_to_async(thread_sensitive=True)` serialises every caller onto one thread. A
synchronous middleware in front of an async view forces a thread per request.

**Renders have a counted cause.** Name what changed identity and how many components
re-ran: an object or array literal passed as a prop, a context value rebuilt every
render, an effect that sets state it depends on. Never infer one from a missing hook.

**Caches hit.** A key built from something that varies per call never hits. A memo
with no eviction is a growing dict. Check the cache sits on the expensive side of the
call, not after it.

## Not a finding

- **Missing `useMemo`, `useCallback` or `React.memo`.** React 19 with the compiler
  memoises automatically, and hand-written memoisation costs allocation and comparison
  for nothing. To claim it is needed, quote a build config with no compiler and count
  the renders.
- **Barrel imports where the bundler tree-shakes.** Vite and modern webpack drop unused
  named exports. A dependency-weight finding quotes the size or the import that defeats
  shaking.
- **A reflex fix whose opposite is also an antipattern.** "Add an index" is paid on
  every write to that table; "use eager loading" pulls a wide relation nobody reads. The
  published catalogue lists both directions, so count and row width decide.
- **A query already batched by something you did not read.** Quote the manager, the
  queryset builder or the `Prefetch` that produces it. Grepping the loop is not enough,
  per the framework-symbol rule in `_schema.md`.
- **Micro-optimisation with no multiplier.** A comprehension against a loop, a set
  against a list of five, one allocation on a path that runs once per request.
- Slow code this PR did not touch, and anything under a test or fixture path.
- Route elsewhere: the dollar cost is `money`; token budgets are `llm-pipeline`; a cache
  key missing the tenant is `tenancy`; a key that collapses two distinct things is
  `red-team`; a slow path with no metric is `observability`; sizing, pooling and CDN
  config are `infra-deploy`.

## Severity

`BLOCKER` only when the new cost crosses a limit this repo already has — a Lambda
timeout, a statement timeout, a lock someone else waits behind. Quote the limit and the
arithmetic that crosses it.

`REQUIRED` when the multiplier is on the normal path and grows with customer data.
`NIT` when it is fixed and small.

## Evidence bar

Quote three things: the unit of work, the loop or caller that repeats it, and the line
the multiplier comes from. Two of the three is a suspicion.

"This N+1 could be slow" is not a finding. "`serializers.py:88` reads
`run.repository.organization` per row inside the loop at :84, and `list_runs` at
`api.py:34` defaults to `limit=100`, so a page issues 101 queries where 2 would do —
`select_related("repository__organization")` on the queryset at :29" is.
