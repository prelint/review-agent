# Specialist: money

Read `_schema.md` first.

**Runs when** the diff touches billing, credits, invoices, vouchers, refunds, usage
metering, cost accounting, or any payment-provider call.

**Why this exists:** money bugs are the highest-cost class in this codebase's record —
duplicate charges, a permanently inflated lifetime-used counter, a $642 unbounded
ingestion run, "billing users too much per one PR" — and no lens owned them. They are
also the only bugs where the fix is a refund and an apology.

**Severity floor:** anything that charges twice, charges the wrong amount, or fails to
charge is `BLOCKER`. Anything customer-visible and wrong is at least `REQUIRED`.

---

## Check

**Every charge is idempotent.** A charge path reached twice — retry, redelivery,
double-click, concurrent worker — must produce one charge. Look for a provider
idempotency key derived from something stable (the run ID, the commit SHA), not from
a timestamp or a UUID generated at call time. A key regenerated per attempt is not a
key.

**The ledger is the truth, and it is append-only.** A correction is a new
compensating entry, never a mutation of an old one. Check that a reversal actually
decrements every counter derived from the ledger — an append-only ledger with a
denormalised total that is never corrected shows the customer a number that is
permanently wrong.

**Derived counters reconcile.** `lifetime_used`, `credits_remaining`, `balance`: can
you recompute each one from the ledger and get the same answer? If a code path writes
the counter without a corresponding ledger row, or writes a ledger row without the
counter, they will drift.

**There is a ceiling.** Any loop, fan-out or per-item cost path must have a maximum.
An unbounded operation on customer input is an unbounded bill. Name the cap or flag
its absence.

**Rounding is decided, not inherited.** Money in floats is a defect. Check the type
is integer minor units or `Decimal`, that rounding direction is explicit at every
conversion, and that a percentage or proration does not silently truncate to zero.

**Currency is carried, not assumed.** An amount without a currency beside it is a bug
waiting for the first non-USD customer.

**Failure paths.** When the provider call fails after local state changed — or
succeeds and the local write then fails — which side wins? Look for a charge recorded
locally before the provider confirmed, or a provider charge with no local record.
Both happen; both need a reconciliation path, not a comment.

**Refunds, disputes and cancellations exist.** A new charge type needs its reversal
path. A new webhook subscription list that omits `charge.refunded` or
`charge.dispute.created` means those events silently never arrive.

**Proration and mid-cycle changes.** Upgrades, downgrades and cancellations mid-period
are where off-by-one-day errors live. Check the boundary explicitly.

**Test-mode leakage.** Test keys, test price IDs or sandbox endpoints reachable from a
production code path.

---

## `security` emits on your behalf

A test key reachable from a production path is a `money` finding, but a diff touching
auth without touching billing dispatches `security` and not you. `security.md` handles
that case directly rather than routing into a lens that is `not-dispatched`.

The coupling is named in both files so a rename or a re-route breaks visibly. If you
change what `money` owns here, read `security.md`'s "Not a finding" entry on
placeholder credentials.

## Not a finding

- Provider-side behaviour you cannot see from this repo, unless the diff assumes
  something specific about it.
- Cost optimisation. Spending too much is a product question, not a defect — unless
  it is unbounded.
- Existing rounding conventions this PR follows consistently.

## Evidence bar

Quote the charge site and the idempotency key's derivation. For a counter drift,
quote both the ledger write and the counter write. For an unbounded path, quote the
loop and show there is no cap between it and the customer's input.

State the failure in money: "a redelivered `invoice.paid` charges the org twice for
run 5370", not "this may not be idempotent".
