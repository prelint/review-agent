# Specialist: tenancy

Read `_schema.md` first.

**Runs when** the diff touches any ORM query, any endpoint returning per-customer
data, any admin path, or any background job that reads customer rows.

**Why this exists:** a multi-tenant B2B SaaS leaks one customer's data to another
through a single missing filter. No other lens owns it — `security` looks for
injection and auth bypass, which is a different failure. This one is quieter and
worse.

**Severity floor:** a confirmed cross-tenant read or write is `BLOCKER`, always.
There is no "minor" data leak.

---

## Check

**Every query is scoped.** For each queryset, `.filter()`, `.get()`, raw SQL or
aggregate added in this diff: is it constrained to the caller's organisation? Trace
the scope back to the request, not to a variable named `org` — a scope derived from a
client-supplied ID is not a scope.

**The scope comes from the session, not the payload.** An `organization_id` in a
request body, query string or path parameter is attacker-controlled. It may be used
to *narrow* within the caller's own tenant. It may never be the only thing that
establishes which tenant the caller is in.

**Object-level checks on every by-ID lookup.** `get(pk=...)` on a customer-owned
model must also constrain the tenant, or a valid ID from another org returns another
org's row. Look for `get_object_or_404` and `.get(id=...)` without a tenant term.

**Related traversals re-scope.** `obj.related_set.all()` inherits the parent's scope
only if the parent was scoped. A chain that starts from an unscoped root is unscoped
all the way down.

**Admin and internal paths.** Staff endpoints legitimately cross tenants. Confirm the
permission gate exists, is checked before the query, and cannot be reached by a
normal session. An internal path with no gate is the same defect with better
paperwork.

**Aggregates and counts.** `count()`, `sum()`, `exists()` leak through totals even
when no row is returned. A count that spans tenants tells you a competitor's volume.

**Background work carries its scope explicitly.** A task enqueued with an object ID
and no tenant re-derives scope at execution time — from where? Celery tasks, cron
jobs and webhook handlers run without a request; they must take the tenant as an
argument and re-assert it.

**Caches are keyed by tenant.** A cache key without the org ID serves one tenant's
value to another. Check every new `cache.get`/`cache.set` and every memoised helper.

**Bulk operations.** `update()`, `delete()`, `bulk_create()` on an unscoped queryset
is a cross-tenant write. These do not fire model signals, so nothing downstream
catches it either.

**New models.** Does the model have a tenant foreign key at all? A customer-owned
table without one cannot be scoped, and every query against it is a future leak.

---

## Not a finding

- A model that is genuinely global (feature flags, plans, currency tables).
- A query already scoped by a manager default, if you can quote the manager.
- Tenant checks in test fixtures.
- Existing unscoped queries this PR did not touch.

## Evidence bar

Quote the query and the line that establishes the scope — or the absence of one.
"This looks unscoped" without the queryset quoted is not a finding.

For a `BLOCKER`, state the concrete path: which endpoint, which caller, which row
they get that is not theirs.
