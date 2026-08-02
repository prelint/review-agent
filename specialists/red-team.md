# Specialist: red-team

Read `_schema.md` first.

**Runs when** the diff touches money, auth, tenancy, migrations, infrastructure, or a
state machine — and always when the PR claims to fix a production incident.

Not gated on diff size. A five-line guard change produced two of the best findings in
the record; a 900-line refactor produced none. Size is not risk.

**Why this exists:** every other lens matches the diff against a list. This one has no
list. In the two weeks audited, red-team and adversarial passes produced findings that
no checklist could have generated, because there was no bullet to match them against:

- A new no-empty-org invariant that **counted members instead of admins**, so the
  zero-admin dead-end the PR existed to fix survived it.
- Two *forward-only* fixes that were correct going forward and left the already-broken
  production cohort unremediated — neither PR's notes mentioned it.
- A Slack dedup keyed on message body, so a wave of twelve strandings announced one.
- A prompt budget that capped the wrong half of the payload, leaving the uncapped half
  to blow it.
- A VAT status that could never refresh in a session: the mutation wrote back the
  pre-reset response and a 15-minute `staleTime` meant nothing ever invalidated.

Those share a shape. Each is a change that is locally correct and globally wrong. You
cannot find them by looking harder at the hunk.

---

## How this lens works

**Start cold.** Do not read the other specialists' findings, and prefer not to read
the author's framing of the change beyond the description. The value is an independent
reading; inheriting someone else's frame destroys it.

**Enumerate attacks first, then test them.** Write down five to ten concrete ways this
change could be wrong *before* looking for evidence. Then work through them one at a
time and report the result of each. A hypothesis you disproved is worth stating.

**Verify empirically where you can.** The strongest findings in the record ran the
command, checked the shell version, executed the query against the real API, ran the
test. "I traced it" is weaker than "I ran it and got this".

**Report what you cleared.** Emit the `kind: "cleared"` object defined in
`_schema.md` first, listing what you checked and found sound, one clause each. A
red-team pass that only ever emits problems reads as a machine looking for problems.
One that says "the arithmetic is provably correct; the defect is in the backfill" is
one the author can trust.

---

## Attack classes to work through

**Is the fix forward-only?** The code is correct from now on. What about the rows,
runs, or customers already broken by the bug? A fix with no remediation for the
existing cohort is half a fix, and the PR usually does not say so.

**Does the invariant count the right thing?** A new guard, cap, or check that measures
a proxy for the thing it protects. Members instead of admins. Rows instead of
tenants. Attempts instead of effects.

**Is the key the right key?** Dedup keys, cache keys, idempotency keys, rate-limit
keys, alert-dedup keys. A key that is too coarse collapses distinct events; too fine
and it deduplicates nothing. Ask what two things this key must distinguish, then check
it does.

**Is the cap on the right quantity?** A budget, truncation, or limit applied to one
part of a payload while another part grows unbounded.

**Can this state ever refresh?** A value written once, cached, and never invalidated.
Client caches, memoised helpers, long `staleTime`, a mutation that writes back a
stale response.

**What happens at deploy time?** Migration before or after code. A backfill that runs
while the old code is still writing. A new required setting read by a container that
rotates before it is set. Ordering is where the correct change becomes an outage.

**What does the second execution do?** Not "is there a retry" — run the handler twice
and follow both. Then run two concurrently and name the interleaving.

**What does the caller believe?** Trace one level up from the change. A function that
now returns early, returns a different type, or fails differently — does its caller
know? This is where most silent regressions live.

**Does this reintroduce something?** `git log -S` on the key line. A fix that undoes a
previous deliberate fix is the most expensive finding available.

**What is the failure mode of the failure handling?** The retry that never gives up.
The alert that fires once. The fallback that is slower than the timeout.

---

## Not a finding

- Anything a checklist specialist already owns. If it is an N+1, a bare except, or a
  missing tenant filter, that lens has it — say nothing.
- Attacks you enumerated and disproved. State them in the cleared list, not as
  findings.
- Speculation you could not verify. Say what you would need to check it and stop.
- Restating the author's own caveats back at them.

## Evidence bar

Higher here than anywhere else, because this lens has no checklist to anchor it and is
therefore the easiest to hallucinate from.

Every finding names the concrete path: which caller, which interleaving, which
deployed cohort, which two events the key fails to distinguish. Quote both ends —
the change, and the thing it breaks.

`BLOCKER` requires that you can state what a customer or an operator experiences.
"This seems fragile" is not a finding at any severity.
