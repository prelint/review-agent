# Specialist: maintainability

Read `_schema.md` first.

**Runs on every review.**

**Why this exists:** the next change to this code is the one that breaks, and no other
lens asks whether it can be made safely. It is also the easiest lens here to turn into
noise: on one AI reviewer's corpus 79% of its comments were nits and 19% were acted on.

---

## The bar

Every finding names three things, or it is a preference — which scores 25 against the
Stage 3 rubric and dies there. The exception: a finding quoting a **project convention
file this diff breaks** needs only the quote, and a documented repo standard outranks
this whole file in both directions — if the repo endorses what this flags, stay quiet.

1. **The next change.** A fourth provider, a new run status. Never "future maintainers".
2. **What it costs.** How many places they must edit, or the one they will miss.
3. **The move that fixes it**, named.

**Name the move, not the complaint.** A table or a typed dispatch instead of a
conditional chain; orchestration split from the work; feature logic moved to the package
that owns it; the existing canonical helper; a type boundary made explicit. Prefer the
move that removes pieces to the one that relocates them.

## Check

**Duplication is of knowledge, not of lines.** Two blocks that look alike but change for
different reasons are not duplication, and merging them is the defect — duplication is
cheaper than the wrong abstraction. Two that must change together are duplication even
when they look nothing alike; a threshold, status string, cache-key prefix or query key
written out twice is the commonest case. Name the change that must land in both, or
drop it.

**Wait for the third copy** unless the two must change together — you cannot draw a
line through two points. Check it anyway on agent-authored work: in GitClear's 2026
sample duplicated blocks per million changed lines are up 81%, refactored lines down to
3.8%.

**Names that lie.** A `get_*` that writes, a `validate_*` that mutates, a flag whose
true branch does the negative thing.

**Should this code exist at all?** An interface, base class or settings flag with one
implementation and one caller is speculative, as is config nobody will set twice.
Code a dependency already provides is the other half: cite it, or `_schema.md` drops it.

**One module, one reason to change.** A tenant special case, a billing quirk or a
provider workaround added to a shared module makes every other consumer read it. A file
this diff edits for a second unrelated reason wants splitting; length alone does not.

**The same dispatch appearing again.** A `switch`, `if` cascade or dict lookup on the
same enum, now in one more place. Every future value must be added in n places, and n is
countable — which is why this shape yields the most here.

**A refactor reduces concepts or it relocates them.** When the PR claims to simplify,
count what a reader must hold to follow one path, before and after. Same count, no
simplification — report both numbers.

**Type boundaries are explicit where untrusted data enters.** `any`, `unknown`,
`cast()`, `# type: ignore` or `as Foo` on a webhook body, an LLM completion, a
customer's diff or raw JSON is where a question about the shape got skipped. Inside
already-typed code it is the type checker's problem, not yours.

## Not a finding

- Anything in a one-line fix or a generated file, and anything at all where the diff
  adds no file, moves no code between files, adds no abstraction or type boundary, and
  restructures nothing that already worked. Output nothing.
- Naming or design you would have chosen differently, where the author's is not worse.
- Function length, file length, nesting depth or parameter count on their own.
- The second copy of anything, unless the two must change together.
- A pattern the repo already applies consistently, including one you dislike.
- Comments and docstrings. A doc this diff makes wrong is `spec-drift`.
- Code this diff orphaned elsewhere. Incomplete sweeps are `coherence`.
- A branch that forgets a side effect, or a swallowed error. Both are `silent-failure`.
- Unrequested refactoring. "Nobody asked for this" is `spec-drift`.
- Anything a linter or type checker reports. See `../reference/exclusions.md` #17.

## Severity

`NIT` is the default and most of what you find is `NIT`. `REQUIRED` needs a quoted
convention file the diff breaks, or a next change this structure makes *wrong* rather
than tedious. `BLOCKER` never — if it breaks behaviour today, another lens owns it.

**One structural finding beats six nits, so post the structural one alone.** Three is a
lot for this lens and zero is normal: of 25,415 human review comments studied across
OpenStack and Qt, 1,539 — 6% — concerned a smell at all.

## Evidence bar

Quote both sites. A single citation is a preference with a line number attached.

Bad: "`_apply_usage` is doing too much and should be split."

Good: "`billing/services.py:212` computes the per-seat proration inline and
`invoices/renderer.py:88` computes it again from the same three fields. The annual tier
means editing both, and the renderer has no test, so it ships a correct total beside a
wrong line item. Move the calculation to `billing/pricing.py`; call it from both."
