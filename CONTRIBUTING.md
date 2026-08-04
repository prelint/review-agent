# Contributing

An agent reads this skill on every run. Every word costs context. Cut the fat, keep
the function.

## How to write here

**Say it once.** No summary of what you just said, no closing restatement.

**Rule first, reason second.** "Commit each fix alone" before "because an interrupted
run leaves a clean tree." A reader who stops after one sentence should still be right.

**No jargon.** Write what you would say out loud to another engineer. Keep the real
names — `author_association`, `substance_hash`, the ledger. Plain never means vague.

**One idea per sentence.** Three clauses and two dashes is two sentences.

**Cut words that change nothing.** "In practice", "it's worth noting", "simply",
"basically", "of course", "as mentioned above".

**Bold is a lookup key**, not emphasis. About one line in ten.

**No emoji.**

**Tables for real grids** — three or more rows and columns. Two facts are a sentence.

**Bullets for parallel things.** Prose chopped at the commas is not a list.

## What earns its place

Rules, procedures, and the evidence a rule rests on. A design decision gets one
paragraph: the alternative, and why it lost.

**Deleting a mechanism earns that paragraph too.** A rule you drop leaves no trace in
the diff of the file that no longer has it, so it is invisible to every later reader
and to this skill's own review. Record it in `docs/DESIGN.md` under "What the rewrite
dropped" — what it did, and what does its job now. "Nothing does" is a valid answer
and belongs there most of all.

Delete: restated rationale, hedging, "we could also", how the file got this way,
anything visible in the diff.

## Before you commit

Reread the diff and delete:

1. Sentences announcing what the next section does.
2. Paragraphs repeating a rule already stated.
3. Hedging adverbs carrying no real uncertainty.
4. Bold used for emphasis rather than lookup.
5. Every remaining word that does not change the meaning.

Then check: does the first line of each section state the rule?

## Reviewing a PR here

**Every PR to this repo is reviewed by this skill.** No exceptions, including PRs that
change the skill itself — especially those. It is the only repo where we control both
sides, so it is the only place a defect in the skill shows up as a defect in its own
review.

Run it, then read its output against what the human reviewers found. Anything they
caught and it did not is a finding about the skill, and it goes in `docs/DESIGN.md`
with the evidence. That is how `coherence` got written: three findings in a row that
external reviewers caught and no lens owned.

Same bar for the review itself. `reference/output.md` sets the caps — 2,000 visible
characters, five non-blocking findings, verdict on line one. Hold human comments to it
too.

A file that grew without gaining a rule is a finding.
