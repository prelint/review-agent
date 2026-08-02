# Specialist: api-contract

Read `_schema.md` first.

**Runs when** the diff touches a Django Ninja router or schema,
`frontend/src/generated/openapi.json`, a wrapper under `frontend/src/features/*/api/`,
or any code that builds a response body.

**Why this exists:** three endpoints in the record silently changed from returning the
whole list to returning the first 50 rows, and the PR description itself said external
bearer-token clients would break. Nothing automatic could have caught it: the Ninja
schema was unchanged, so the generated spec was byte-identical and TypeScript still
compiled. A spec diff compares structure and cannot see semantics.

**Severity floor:** a break reaching a consumer outside this repo — the CLI, a
bearer-token client — is `BLOCKER`. This PR cannot update them.

---

## The three surfaces

One schema change has three surfaces here, and they go stale one at a time.

| Surface | Path | Goes stale when |
|---|---|---|
| Ninja schema and route | `backend/**/api.py`, `schemas.py` | never; it is the source |
| Generated spec | `frontend/src/generated/openapi.json` | nobody re-ran the generator |
| Hand-written wrapper | `frontend/src/features/*/api/` | it declares its own type instead of importing the generated one |

**The wire truth is the Ninja schema plus the route decorator, never the committed
spec.** The spec is generated, and Pydantic's validation and serialisation schemas
handle aliases differently, so `alias`, `serialization_alias` and `alias_generator` are
where the published name and the emitted name part company. Quote the field, the
`response=` argument and `by_alias`.

**A wrapper that imports the generated type is covered by `tsc`** — a mismatch is a
type error and `exclusions.md` #17 drops it. Only a wrapper holding its own local
interface drifts silently. Check which kind it is first.

---

## Check

**Direction decides whether a change breaks.** One rule generates the table: widening
what you accept is safe, widening what you emit is not. Reversing request and response
is the largest false-positive class here.

| Change to a field | In a request | In a response |
|---|---|---|
| Added | breaks if required | safe |
| Removed | safe | breaks every reader |
| Optional becomes required | breaks | — |
| Required becomes optional or nullable | safe | breaks |
| Enum value added | safe | breaks an exhaustive consumer |
| Enum value removed | breaks | safe |
| Type narrowed | breaks | safe |
| Type widened | safe | breaks |

**Semantics change while the shape does not.** A slice, cap, filter, default or
ordering added inside a handler emits the identical schema and a different answer. That
is the incident above. Read the handler body, not the response annotation.

**Status codes, paths and error bodies are contract.** A `200` with an empty list that
became `404`, a `201` that became `200`, a renamed path with no alias, a new endpoint
inventing its own error object so callers parse two formats.

**Auth breaks in one direction only.** Public becoming authenticated, or a new scope or
token requirement, belongs here. Authenticated becoming public is `security`, as is a
stack trace or SQL string in an error body.

**Pagination added to a live endpoint breaks twice.** The body becomes
`{"items": ..., "count": ...}` where it was an array, and callers that send no `limit`
now get one page.

**A break inside `/api/v1/` has no escape hatch.** No header negotiation, no date
pinning. A change that cannot be made additive needs a parallel field, a `v2` path, or
a stated window — `Deprecation` and `Sunset` headers (RFC 9745, RFC 8594) plus a way to
find who still calls it. "We will tell them" is not a path.

**Outbound webhook and event payloads are published interfaces.** A field removed from
what this service sends breaks subscribers exactly as a response change does. Delivery
and dedup are `idempotency`; the payload shape is yours.

---

## Not a finding

- A new endpoint, or a new optional field on a response. Additive changes are safe
  unless you can quote a consumer that rejects unknown keys.
- A schema no route reaches. Grep for it in a `response=` or a body annotation first.
- Paths that are not `/api/v1/` — admin, health checks, and the inbound Stripe, GitHub
  and Stytch receivers. Those contracts belong to the sender or to one in-repo caller.
- `openapi.json` churn with no schema behind it: key order, a description, a version.
- A Python attribute renamed while `Field(alias=...)` holds the wire name steady.
- A wrapper whose types come from `generated/openapi.json`. `tsc` owns it.
- A missing page cap on an endpoint that never had one — that is `resource-limits`. A
  cap *added* to an endpoint that had none is yours.
- A description that does not match the diff. That is `spec-drift`.

## Severity

**An acknowledged break is still a break.** A PR description saying external clients
will break states the problem. It is not a migration, a version bump, or a window.

`BLOCKER` when a consumer outside this repo breaks, or when the deployed frontend
breaks against the backend this PR ships — they deploy separately, so the old client
meets the new server for the length of the rollout. `REQUIRED` when every broken
consumer is fixed in this same diff. `NIT` for a stale spec with nothing behind it.

## Evidence bar

Every finding names three things. Missing one, you have a suspicion.

1. **The difference on the wire** — old bytes against new bytes at the serialised
   boundary, not the Python or TypeScript type.
2. **The consumer** — a named wrapper file, the CLI, or a bearer-token client. This is
   also your `condition`. "Clients may depend on this" is not a consumer.
3. **What that consumer does with the new bytes** — the crash, the missing rows, the
   wrong render.

"This changes the response shape and could break clients" is not a finding. "`list_runs`
at `backend/apps/runs/api.py:88` gained `[:50]` while `response=list[RunOut]` is
unchanged, so `openapi.json` is byte-identical and `tsc` passes — a bearer-token client
that pages until an empty result stops at 50 and reports 50 runs for an org with 3,200"
is.
