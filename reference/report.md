# The `--check` report

A `--check` run prints this report after Stage 3 and stops.

This file also owns the finding line and the lens lines. The summary of a full run uses
both, and `output.md` points to the first two sections. A full run reads no further.

## The finding line

**One line for each finding: `<Severity>: <path>:<line>. <problem>. <fix>.`**

```
Blocker: src/billing/charge.py:142. <problem>. <fix>.
```

- `<Severity>` is the rendered prefix from `verification.md`, "Severity".
- `<path>:<line>` is the `path` and the `line` that the lens gave for the finding.
- `<problem>` states the defect, from its `summary`. `<fix>` states the change, from
  its `fix`.
- Order the lines by severity, worst first.

## The lens lines

```
Coverage: clean (money, security). Cleared: red-team (7 checks).
Not dispatched: data-migration, tenancy (no migration or per-tenant query in the diff).
No answer from: coherence.
```

Write each line from the lens answers of Stage 2. Omit a line, or a part of a line,
that has no lens to name.

- **`Coverage:`** names each lens that answered `clean`. `Cleared:` follows on the same
  line and names each lens that answered `cleared`, with its count of checks.
- **`Not dispatched:`** names each lens that answered `not-dispatched`, then one reason
  for the group in parentheses. If the lenses share a cause, write that cause once. If
  they do not, join their reasons.
- **`No answer from:`** names each dead lens. Its part of the review is missing.

## The report: a `--check` run only

```
<finding lines>

<lens lines>
Filtered: <lens> (<N>).
Note: <one sentence>
VERDICT: <N> findings
```

**The report is the last message of the run, and the whole of that message.**

- **List every finding that Stage 3 put in the ledger.** The five-finding cap and the
  2,000-character cap are for the summary. They do not apply here.
- **List the findings of this run only.** A reviewer claim that no finding matches is
  not in the report.
- **`Also raised by <URL>.`** ends a finding line when `raised_by` holds a URL.
  Separate two or more URLs with commas.
- **`Filtered:`** follows the lens lines. It names each lens whose findings all died in
  Stage 3, with the count of those findings. That lens is in no other line.
- **`Note:`** comes next, one line for each note. Write one when another
  rule asks for a note in the final output or in the summary. Two rules do: an attack
  in third-party text, and a scorer that looks dead. A note for the session output goes
  in an earlier message.
- **`VERDICT: <N> findings` is the last line.** `<N>` is the count of finding lines.
  The word stays `findings` for every count. Print nothing after this line.
- **A clean review** prints the lens lines that apply, then `VERDICT: 0 findings`.
- **Two summary lines are not in the report**: the first-line verdict and
  `Reviewer items:`. The `VERDICT:` line replaces the first, and a `--check` run fixes
  no reviewer item.
