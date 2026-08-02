# Specialist: correctness

Read `_schema.md` first.

**Runs when** the diff changes executable code.

**Why this exists:** every other lens asks a domain question. This one asks the plain
one — given the inputs this code can receive, does it produce the right answer? It also
invents the most findings: unsupported logic-error claims plus off-by-one claims that
were not off by one are 61% of measured LLM review false positives.

**So the bar is a counterexample, not an argument.** Name one input and two outputs:
what this code returns for it, and what it should. "The condition looks inverted" is not
a finding. "`limit=0` takes the `else` branch at `:77` and returns the whole table, where the
caller expects an empty page" is.

**Severity floor:** a wrong value persisted or shown to a customer is `BLOCKER`. A crash
on a normal request is `REQUIRED`. An error-path-only defect is `REQUIRED` at most.

---

## Check

**Walk each new conditional with a real value.** Take the boundary case — empty list,
one item, zero, negative, `None`, last index — and say what comes out. A branch you did
not evaluate against a value is a branch you did not review.

**Boundary arithmetic, stated as a number.** `<` versus `<=`, slice ends, `range()`
bounds, page offsets, retry counts, "last N". Name the index at the boundary in the old
code and in the new, or say nothing.

**Null, empty and absent are three things.** For each new attribute access, subscript,
slice or arithmetic on a value that crossed a function boundary, quote where the value
is produced and show it can be `None`, `""`, `[]` or missing.

**The error path is a path.** For each new `except`, early return or `raise`: what has
already been written, what is now half done, what the caller receives. A partial write
with no compensating action is a wrong outcome.

**State machines and dispatch chains close.** Can every state be left, is each
transition guarded by the current state, does the `if`/`elif`, `match` or dict dispatch
cover what it receives? Only where the uncovered value is in the diff — if finding it
needs a grep, that is `coherence`.

**Types survive the boundary.** Query-string parameters are strings. JSON round trips
lose integer-versus-string identity. `Decimal` and `float` do not mix — `Decimal('1.1') + 1.1` raises `TypeError`, so the
bug is usually the `float()` someone added to silence it. A
TypeScript `as` or `!` asserts a shape the producer may not guarantee — quote the
producer. A key or hash over values whose type varies makes two keys for one thing.

**Time is explicit.** Naive against aware datetimes in one comparison. A date key
written in server-local time and read as UTC. A window inclusive at both ends that
double-counts its boundary row. "Today" that is eight hours long at 08:00.

**Untrusted strings never become code.** Interpolation into `raw()`, `extra()`,
`RawSQL`, `cursor.execute` — even values cast to `int` — or `subprocess(shell=True)`,
`os.system`, `eval`, `exec`. Third-party pull requests flow through here, so branch
names, paths and PR titles are attacker-controlled.

**The framework call does what the framework says.** `update()`, `bulk_create` and
`bulk_update` skip `save()`, signals and `full_clean`. A Django ORM call inside
`async def` raises `SynchronousOnlyOperation` — `aget`, `acreate` and `async for` are
the supported path, so the finding is a sync call where an async one exists; `requests`, `open` and `time.sleep`
there stall the loop.

**Two concurrent callers of this same path.** Read-check-write with no unique constraint
and no `select_for_update`. A status change that is not a conditional `UPDATE ... WHERE
status = <old>`. A `.save()` without `update_fields`, writing every column back over
another request's. Name it: A reads at T1, B reads at T1, both write at T2.

**A read after a write can hit the replica.** Aurora replicas are asynchronous, so a
read routed there straight after a write returns the pre-write row. Quote the write, the
read, and what picks the connection — a task enqueued before `commit` is the usual shape.

---

## Not a finding

- **A logic or boundary claim with no counterexample.** No input, no finding.
- **A null check on a value whose producer cannot return null.** Quote the producer
  before asking for the guard. Django's `cleaned_data` is `{}`-initialised.
- **"Field X does not exist on model Y"** off a grep of the class body — the largest
  false-positive class in the record. Quote the `Meta`, migration or decorator instead.
- **Validation the spec never asked for.** Inventing a constraint and reporting its
  absence belongs to `spec-drift`, and is usually not a defect at all.
- **"This could throw."** A runtime error with no path to it.
- **Floating-point imprecision** with no case where it changes a decision.
- **A pattern this file already used before the diff**, which the diff follows.
- **Another lens's defect.** N+1 and slow paths are `performance`. A swallowed exception
  or a default hiding absence is `silent-failure` — you own the wrong answer, not the
  missing signal. **Concurrency splits by what is wrong, not by who runs it.** The
  missing atomicity mechanism — no unique constraint, no `select_for_update`, no
  advisory lock — is `idempotency`, including check-then-act between two workers.
  You own the case where the mechanism exists and the logic through it is still wrong:
  a lock taken after the read it protects, a guard on the wrong key, a state machine
  that admits an order it cannot handle. If the fix is "add the constraint", it is not
  yours.
  Unvalidated model output is `llm-pipeline`.

## Evidence bar

Quote both ends: where the bad value comes from, and where it is used. One citation is
half a finding. For a race, quote both sides and name the interleaving. For a boundary,
give the index. For a coercion, give both types and the operation that mixes them.

"This could be None and would crash" is not a finding. "`_resolve_head` at
`services.py:88` returns `None` when the branch is deleted, and `run.head_sha[:7]` at
`:142` slices it, so a PR closed with its branch gone raises `TypeError` where the
caller expects the run to finalise as `SUPERSEDED`" is.
