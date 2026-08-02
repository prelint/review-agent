# Specialist: data-migration

Read `_schema.md` first.

**Runs when** the diff adds or edits a file under `*/migrations/`, changes a model
field, or adds a backfill command, a data-rewrite script, or raw DDL.

**Why this exists:** `manage.py migrate` runs **before** the ECS task swap, and the
background-task stack updates two to five minutes later. Every migration lands on a
database the deployed image is still reading and writing. Two bugs shipped from that
window: a `NotNullViolation` on `decision_recommendation`, and a backfill that rewrote
a column the old non-lot-aware code was still mutating. `infra-deploy` owns the
rollback path for infrastructure; this lens owns it for data.

**Ask of every operation: does the deployed image still work against this schema?** New
code ships after the migration and is safe by construction. Old code is what breaks,
and it is not in the diff.

**Severity floor:** a migration that makes the deployed code raise is `BLOCKER`. So is
one that cannot be reversed once rows exist under the new schema.

---

## Check

**A new `NOT NULL` column needs a database-side default.** Django emits `ADD COLUMN
... NOT NULL DEFAULT x` then `DROP DEFAULT`, so an INSERT from the old image — which
omits the column — raises `NotNullViolation` for the whole rotation. The project rule
is `null=True` on every new column (`.agent/rules/backend/coding-standards.md`,
"Migrations"); Django 6's `db_default` is the other correct answer.

**Drops, renames and type changes break reads, not just writes.** Django selects an
explicit column list, so once a column is gone every query against that model from the
old image raises `ProgrammingError` — including code that never touched the field.
Two-deploy split, per `docs/guides/database-migrations.md`.

**The destructive-migration CI check has four blind spots.**
`.github/workflows/backend.yml` blocks `RemoveField`, `RemoveModel`, `DeleteModel`,
`RenameField` and `RenameModel` when `models.py` in the *same app* also changed. It
cannot see a drop written as `RunSQL` or inside `SeparateDatabaseAndState`, a surviving
reference in another app, an edited rather than added migration, or a `# safe-removal:`
comment whose reason is untrue. Those four are yours.

**A backfill races the old code.** A `RunPython` rewriting rows the running image still
mutates by the old rule loses whichever write lands second. Name which writer wins. The
fix is a backfill restricted to rows the old code cannot reach, a reconciler after
rotation, or a management command run post-deploy.

**Reads inside `RunPython` go to the replica.** `config/db_router.py` registers
`ReadReplicaRouter` in `DATABASE_ROUTERS` for every environment, and `db_for_read`
returns `readonly` whenever that alias exists — it does in production. A queryset
omitting `.using(schema_editor.connection.alias)`, which Django's migration docs
require, reads lagged rows while writing to the writer, so an `.exists()` guard misses
what the same migration just wrote.

**Backfills are chunked, resumable and safe to run twice.** One `UPDATE` across a whole
table holds row locks in a long writer transaction, which lags the replica for every
reader. Look for keyset batches, a short transaction each, and a `WHERE` excluding done
rows so a second run is a no-op. `atomic = False` leaves partial data on a crash:
correct when that `WHERE` is self-limiting, corruption when it is not.

**Reverse is real.** `RunSQL` with no `reverse_sql` makes the migration irreversible,
so `migrate <app> <n>` fails outright. Then the harder question: rows written under the
new schema — what does the reverse do to them? A structurally reversible migration that
discards them is not a rollback.

**Three things still take `ACCESS EXCLUSIVE` on Aurora Postgres 16.** A type change
outside the safe conversion set, `SET NOT NULL` without a validated `NOT VALID` CHECK
first, and any index or unique constraint built without `CONCURRENTLY`. A failed
concurrent build leaves an `INVALID` index and the retry fails on "relation already
exists", so the migration says how to recover or it is a stuck deploy.

## Not a finding

- Adding a nullable column, a new table, or an index built `CONCURRENTLY`.
- `ADD COLUMN` with a non-volatile default, and `DROP COLUMN`. Metadata-only on
  Postgres 11 and up — no rewrite, no long lock. Calling either a lock risk is the most
  common false positive in this domain. A *volatile* default does still rewrite.
- `atomic = False`. `CONCURRENTLY` requires it; it is not a missing transaction.
- `SeparateDatabaseAndState` with empty `state_operations`. Phase two of a staged drop.
- `RunPython.noop` reversing a backfill of derived data, where the migration says so.
- A destructive migration bundled with model changes in the same app. CI blocks it.
- Squashed migrations and the originals they replace. Already applied.
- A backfill spanning every organisation. Migrations are global by construction.
- "Add a rollback plan" naming no operation. The procedure is in the guide.

## Severity

Table size sets the likelihood band, not the operation. A lock claim against a table of
four hundred rows is `remote`; against `reviews_reviewrun` it is `likely`. If you cannot
size the table the band is `unverified`, never `remote`. A window break is `likely` —
rotation happens on every deploy.

Route out by name: the pipeline, the task definition, an env var the migration task
lacks — `infra-deploy`. A backfill saturating the pool or queue — `resource-limits`. A
credit backfill's ledger invariant — `money`. A half-swept rename whose column still
exists — `coherence`.

## Evidence bar

Quote the operation **and** the code in the deployed image that it breaks. New code is
not evidence; it ships after the migration. For a backfill, quote the loop or `UPDATE`
and the `WHERE` that makes a second run a no-op, or show there is none. For a lock, name
the table and how you sized it.

"This migration may not be backward compatible" is not a finding.
"`0045_add_decision_recommendation.py:14` adds `decision_recommendation` with
`null=False, default=''`, so Django drops the database-side default; the pre-rotation
worker's INSERT at `apps/reviews/services.py:88` omits the column and raises
`NotNullViolation` for the 30 to 120 seconds of the ECS swap" is.
