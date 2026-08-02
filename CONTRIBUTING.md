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

Same bar for the review. `reference/output.md` sets the caps the agent posts under —
2,000 characters, five non-blocking findings, verdict on line one. Hold human comments
to it too.

A file that grew without gaining a rule is a finding.
