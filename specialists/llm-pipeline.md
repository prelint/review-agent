# Specialist: llm-pipeline

Read `_schema.md` first.

**Runs when** the diff touches prompts, model calls, evals, token budgets, provider
configuration, or any code that parses model output.

**Why this exists:** this codebase ships prompt packages and runs models in
production, and no lens owned that. From the record: a Lambda vendoring the prompt
package by value so a prompt change did not reach it; a large system prompt
de-duplicated with drift between copies; a per-run budget ceiling; a provider mode
switch.

---

## Check

**Prompt and consumer ship together.** A prompt lives in a package; a consumer
vendors, pins, bundles or caches it. If this diff changes the prompt but a consumer
resolves it by value at build time, that consumer keeps the old prompt after deploy —
and now production runs two different prompts. Find every consumer, quote how each
resolves the dependency.

**Single-homed strings stay single-homed.** A de-duplicated prompt fragment has one
home. Check that no copy survives elsewhere, and that any guard test actually
targets the phrases that are now single-homed rather than phrases that were never
duplicated. A test that passes identically before and after the change guards
nothing.

**Model output is untrusted input.** Anything parsed from a completion — JSON, a file
path, a shell fragment, an ID, a URL — crosses a trust boundary. Check for schema
validation before use, and for what happens on malformed output. Never a bare
`json.loads` on a completion with no failure path. Never model output interpolated
into a query, a command, or a file path.

**Token budget has a ceiling and it is enforced.** A per-run cost cap, a max input
size, a truncation rule. Check the cap is checked *before* the call, not tallied
after. An unbounded input from a customer is an unbounded bill — this is the same
defect the `money` lens sees from the other side.

**Truncation preserves what matters.** A prefix-only cap on a body drops everything
after it. If a downstream decision depends on content that can appear anywhere,
prefix truncation silently makes that content invisible. This is in the record. Ask
what the truncated text was for, then check the cap preserves it.

**Provider fallback is real.** A secondary provider or model configured but never
exercised, or exercised with different parameters, different tokenisation, or a
different output shape. A fallback that has never run is a hypothesis.

**Model identifiers are current and pinned deliberately.** A hardcoded model string
that is now outdated, a floating alias where a pin was intended, or a pin where the
newest model was intended.

**Retries are bounded and non-recursive.** Retrying a failed completion with the
failure appended to the prompt grows input on every attempt. Check the growth is
capped.

**Evals cover the change.** A prompt change with no eval case is a behaviour change
with no test. If the repo has an eval suite, a prompt diff should touch it.

**Determinism where it is assumed.** Temperature, seed, and sampling settings on a
path whose caller assumes a stable answer — a cache key, a dedup key, a comparison.

---

## Not a finding

- Prompt wording and style. Not reviewable from a diff.
- Model choice as a product decision.
- User content in a system prompt, by itself. See `../reference/exclusions.md` #14.
  The finding is what happens to the *output*, not that untrusted text went in.

## Evidence bar

Quote the prompt definition and the consumer's resolution. For a truncation finding,
quote the cap and the downstream consumer that needs the dropped content. For an
output-trust finding, quote the parse and the sink.
