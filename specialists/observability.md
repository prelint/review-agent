# Specialist: observability

Read `_schema.md` first.

**Runs when** the diff adds a failure path, background work, an external call, or a
new operational mode.

**Why this exists:** from the record, a silent fleet freeze with no signal anywhere.
The code was correct enough to fail quietly, and nothing told anyone. Every other lens
asks whether the code works; this one asks whether you would find out when it stops.

**Severity ceiling:** `REQUIRED` at most, except where a silent failure loses money or
data — then `BLOCKER`, and `silent-failure` will usually have it too.

---

## Check

**New failure paths emit something.** For each new error branch, timeout, or
degradation added in this diff: is there a log at an appropriate level, a metric, or
an alarm? A caught exception with no signal is invisible.

**Signals carry correlation.** A log line without the org, the run, the request or the
event ID cannot be tied to the incident it belongs to. Check new log calls carry the
identifiers a responder would filter on. Structured fields, not interpolated prose.

**Logs do not carry secrets or PII.** Tokens, keys, full request bodies, email
addresses, customer content. Check new log calls and new exception messages —
exception strings end up in logs and in error trackers.

**Log level matches consequence.** A failed payment at `debug`. A retry at `error`.
Both are wrong in the same way: they teach the responder to ignore the level.

**New background work is observable.** A task, cron or worker added here — can you
tell it ran? That it succeeded? How long it took? A scheduled job with no
heartbeat and no failure alarm fails silently forever, which is exactly the freeze in
the record.

**A stall is distinguishable from idle.** For queues, leases and pollers: is there a
signal that separates "nothing to do" from "stuck"? Absence of activity is not
absence of a problem, and only an explicit heartbeat tells them apart.

**Alarms exist for the new mode.** If this diff adds a resource, a queue, or a
dependency, is anything watching it? A new stack with no alarm is a new blind spot.

**Cardinality is bounded.** A metric dimension or log field keyed by something
unbounded — a user ID, a URL, a commit SHA — will cost money and break the dashboard.

**Errors reach the tracker once.** Caught, logged, and re-raised produces two reports.
Caught and swallowed produces none. Check which.

---

## Not a finding

- Missing logs on a happy path that already has metrics.
- Log wording and formatting.
- Absence of tracing where the project has no tracing.
- Verbosity preferences.

## Evidence bar

Quote the new failure path and show there is no signal on it. Say what a responder
would be looking at, and what they would not see.

"Should add logging" is not a finding. "The `except TimeoutError` at poller.py:142
returns silently, so a wedged lease produces no log, no metric and no alarm — the
fleet reads as idle" is.
