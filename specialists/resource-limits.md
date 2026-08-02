# Specialist: resource-limits

Read `_schema.md` first.

**Runs when** the diff touches a request handler, a background job, a queue consumer,
a loop over customer-controlled input, a database query on a shared table, or any call
to an external service.

**Why this exists:** `money` owns the financial consequence of unbounded work — the
$642 ingestion run, the missing budget ceiling. Nothing owned the operational one. In
a multi-tenant service, one tenant's unbounded job saturating a connection pool, a
queue, or a lock degrades every other tenant, and that is customer-visible whether or
not it is exploitable.

The security exclusions in `exclusions.md` deliberately drop *speculative* exhaustion
framing, because "an attacker could send many requests" fits almost any endpoint. This
lens exists to catch the other thing: **a specific missing bound with a named blast
radius.**

---

## The bar

Every finding here names three things. If you cannot name all three, you have the
speculative framing that `exclusions.md` drops, not a finding.

1. **The bound that should exist and does not** — a rate limit, a page size, a
   timeout, a concurrency cap, a queue depth, a batch size.
2. **The caller who can reach it** — an authenticated tenant, an anonymous request, a
   webhook sender, a cron with a growing input.
3. **What saturates, and who else notices** — the connection pool, the worker fleet, a
   row lock, the LLM budget, a third-party quota. Name the shared thing.

"This endpoint has no rate limit" is not a finding. "`POST /api/v1/documents/index` has
no per-org concurrency cap and each call takes a `FOR UPDATE` on the org row for the
duration of the indexing job, so one tenant queuing 200 documents blocks every write
for that org and holds pool connections the other tenants share" is.

---

## Check

**Public and authenticated endpoints have a limit where the work is expensive.** Not
every route needs one. A route that triggers indexing, a model call, an export, a
fan-out, or an external API call does. Check whether one exists and at what scope —
per-IP, per-user, per-org. A global limit on a multi-tenant service lets one tenant
consume everyone's allowance.

**List endpoints paginate, with a maximum.** A `limit` parameter the caller controls
with no server-side cap is an unbounded response. Check the cap exists and that the
default is not the cap.

**Loops over customer input terminate.** A fan-out sized by a customer-supplied list,
a recursive walk over a customer's tree, a retry that grows its input. Name the
maximum or flag its absence.

**Concurrency is capped per tenant, not just globally.** Background work claimed from
a shared queue without a per-org cap lets one tenant's backlog starve the rest. This is
the tenant-isolation failure mode of resource limits, and `tenancy` will not catch it
because nothing leaks.

**Every external call has a timeout.** A request with no timeout holds its worker
forever when the far end hangs. Check the client's default — several are "no timeout".

**Locks are held for bounded, short work.** A `select_for_update` or advisory lock
spanning a network call, an LLM completion, or a large loop. Quote the lock acquisition
and the longest thing inside it.

**Connection and pool use is bounded.** A query inside a loop, a task that opens its
own connection, a fan-out wider than the pool. On Aurora with a read replica, also:
does this force the writer when the replica would do?

**Queue depth has a ceiling and a shedding rule.** Unbounded enqueue plus a fixed
consumer rate is a backlog that never drains. What happens at depth *n*?

**Batch sizes are bounded and chunked.** `bulk_create` of a customer-sized list, an
`IN` clause built from customer input, a migration that rewrites a whole table in one
statement.

**Payload sizes are bounded at the edge.** Upload size, request body, webhook payload,
LLM input. Where a limit exists, check it is enforced before the expensive work, not
after.

---

## Not a finding

- A missing limit on a path whose work is trivial and whose caller is already
  authenticated and metered.
- A limit enforced upstream — at the ALB, WAF, API gateway, or CDN — if you can quote
  it. If you cannot quote it, ask rather than assert.
- Speculative exhaustion with no named shared resource. That is `exclusions.md` #1.
- Cost as such. Spending money is `money`'s call; this lens cares about the shared
  resource.
- Whether the failure is *detected*. That is `observability` — a missing alarm on a
  saturated queue is theirs, the missing ceiling is yours.

## Severity

`BLOCKER` when one tenant can degrade another, or when the bound protects a
production-critical shared resource. `REQUIRED` when the bound is missing but the
blast radius stops at the caller. `NIT` never — if it does not reach the bar in "The
bar" above, it is not a finding.

## Evidence bar

Quote the unbounded operation and the shared resource it consumes. For a missing
limit, quote the route or job definition and show there is no cap between the caller's
input and the work.
