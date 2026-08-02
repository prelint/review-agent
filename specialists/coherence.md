# Specialist: coherence

Read `_schema.md` first.

**Runs on every review.**

**The question:** the hunk is correct — what does it break that is *not* in the hunk?

**Why this exists:** every other lens judges the change. This one judges the seam
between the change and what was already there. Both halves are right on their own;
together they are wrong, and the older half is outside the diff, so nothing puts them
side by side.

Three consecutive findings on this repo's own PR were this shape, each one created by
the fix for the last:

| Change | What it broke, outside the diff |
|---|---|
| A thread-join fix produced `thread_id = null` on failure | Nothing downstream consumed the null case |
| The null case gained an `unresolvable` status | The silence rule four commits back counted it as closed and suppressed the required warning |

An external reviewer caught both. No checklist lens would have, because there is no
bullet to match — the defect only exists in the pair.

---

## The four shapes

**Contradicted rules.** A new rule, status, default, flag or guard that something
already in the file — or a sibling file — decides differently. Grep for the terms the
new rule governs and read what already decides them.

**Orphaned producers.** A new state, status, error, field or return value that nothing
downstream consumes. Trace it forward one hop: who reads this, and do they handle it?
A value that only ever gets written is a bug with no symptom yet.

**Orphaned consumers.** The reverse: code that reads a field, status or config no
producer sets. Usually a rename or a removal that missed one side.

**Incomplete sweeps and missed call sites.** A string, constant, enum value or icon
changed in three places out of four. A signature change where a sibling implementation
was missed. When the siblings no longer share a builder there is no compile error and
no failing test.

---

## Method

**Work from what the diff introduces, not from the codebase.** For each new name,
status, rule or signature in the diff, one focused grep for what it governs or what it
replaces. Read the hits. That is the budget.

**One grep per named risk. Never a general crawl.** If you cannot name the risk before
you search, you are browsing. Browsing is how a review gets expensive and stays
shallow.

**Trace one hop, both directions.** Forward: who consumes what this produces. Backward:
who produces what this consumes. One hop is almost always enough — the second hop is
where speculation starts.

**Quote both halves.** A finding here always cites two locations: the new code, and
the thing it is incoherent with. A single citation means you have half a finding.

---

## Not a finding

- A new state genuinely reserved for later, if the diff or a comment says so.
- Duplication that is deliberate and documented.
- Anything where you can only cite the new half. That is a suspicion.
- Style inconsistency. This lens is about behaviour and rules, not formatting.
- A contradiction the diff itself resolves — read the whole diff first.

## Severity

`BLOCKER` when the pair silently produces a wrong outcome — a guarantee that no longer
holds, a warning that never fires, a value that never reaches its consumer. `REQUIRED`
otherwise. The severity comes from the consequence of the pair, never from how far
apart the two halves sit.

## Evidence bar

Two citations, always: `file:line` for the new half, `file:line` for the existing half,
and one sentence on what the pair does that neither half does alone.

"These may be inconsistent" is not a finding. "`output.md:112` counts `unresolvable`
as closed, so the silence rule at `output.md:64` suppresses the warning that
`output.md:118` requires — a fixed finding leaves an open thread and nothing says so"
is.
