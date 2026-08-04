# Simplified Technical English

Write prose in ASD-STE100 Simplified Technical English (STE). This file owns the
mechanics: words, verbs, sentence length, and punctuation. `../CONTRIBUTING.md`
owns what to say and in what order. Read both. Neither one repeats the other.

The canonical copy of this file lives in `prelint/prelint` at
`.agent/rules/_global/ste-writing.md`. A third copy lives in
`prelint/prelint-private-worker-agents`. Change the canonical copy first, then
sync this one in the same session.

## Where it applies

Applies to every posted comment, review summary, thread reply, issue body, and
commit message this skill writes. Applies to this repository's own prose too:
`SKILL.md`, the reference files, the specialist files, and the docs.

Does not apply to code, identifiers, command syntax, or quoted output. Does not
apply to text you quote from a reviewer. Quote it as written.

Applies to text you write or edit from now on. Do not sweep existing files to
convert them. A file converts when you next have a reason to touch it.

## Two modes

**Strict** covers procedures, runbooks, safety text, error messages, and UI
microcopy. Apply every rule below, plus the closed STE dictionary, plus both
length caps.

**STE-flavored** covers general prose such as review comments, summaries, PR
bodies, and docs. Apply every rule below except the closed dictionary. The wider
vocabulary keeps enough range to read naturally. Treat the caps as targets, and
split any sentence over 25 words.

The rules below hold in both modes. Only the dictionary and the hard caps differ.

## Rules

**Words**

- Use one name for one thing. Never call the same item by two names.
- Use the short common word. Write start, not begin or initiate. Write use, not
  utilize or leverage. Write help, not facilitate. Write make sure, not ensure.
  Write before, not prior to. Write after, not subsequent to. Write about, not
  regarding. Write get, not obtain. Write show, not demonstrate. Write also, not
  additionally or furthermore.
- Give each word one meaning. "Fall" means to move down, not to decrease.
- No marketing adjectives: seamless, robust, powerful, cutting-edge, effortless,
  world-class, next-generation, revolutionary.
- American spelling.

**Verbs**

- Use the active voice. Write "the parser reads the file", not "the file is read
  by the parser".
- Use a verb for an action. Write "analyze the log", not "perform an analysis of
  the log".
- Do not stack auxiliaries. Write "this improves throughput", not "it is
  important to note that this may help to improve throughput".
- Do not use an "-ing" main verb where a simple tense works.
- Do not use phrasal verbs. Write "start the worker", not "spin up the worker".

**Sentences**

- One instruction per sentence.
- Cap an instruction at 20 words. Cap a descriptive sentence at 25.
- Do not use contractions. Write "do not", not "don't".
- Use the articles a, an, the, this, and these.

**Punctuation**

- No semicolons. Write two sentences.
- No em dashes. The standard permits them. We ban them, decided 2026-08-04,
  because the em dash is the strongest slop tell in our own text. Use a period, a
  comma, or parentheses.

**Structure**

- One topic per paragraph. Cap a paragraph at six sentences.
- Write steps as a numbered vertical list. One action per item. Imperative form.
- Put the condition before the command. Write "If the log is empty, restart the
  job", not "Restart the job if the log is empty".

## Self-lint

Run this before you commit prose, post a comment, or return text.

1. Any sentence over 20 words? Split it.
2. Any semicolon or em dash? Replace it with a period.
3. Any contraction? Expand it.
4. Any passive voice with a known actor? Make it active.
5. Any "-ing" main verb, nominalization, or phrasal verb? Replace it with a
   plain verb.
6. Same thing named two ways? Pick one name.

## What this does not fix

Every rule above is mechanical, and mechanical rules remove the form of slop.
They cannot make a hollow paragraph true. Choosing the right technical noun, and
judging whether a finding is real, stays your job. A comment that obeys every
rule here and reports a bug that does not exist is still a bad comment.

Source: ASD-STE100, https://asd-ste100.org.
