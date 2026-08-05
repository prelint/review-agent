# Simplified Technical English

Write prose in [ASD-STE100](https://asd-ste100.org) Simplified Technical English
(STE). This file owns the
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
microcopy. Every rule below is hard, including both length caps.

**STE-flavored** covers general prose such as review comments, summaries, PR
bodies, and docs. Every rule below still applies. Treat the two caps as targets,
and split anything over 25 words.

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
- When applicable, use an article (a, an, the) or a demonstrative adjective
  (this, these) before a noun. This matches the standard's Rule 4.5, qualifier
  included. Do not add articles to general statements or abstract concepts
  ("Solvents can cause damage to paint"). In a series of items, the article
  before the first noun is enough. Labels take no articles (see Structure).

**Punctuation**

- No semicolons. Write two sentences.
- No em dashes. The standard permits them. We ban them, decided 2026-08-04,
  because the em dash is the strongest slop tell in our own text. Use a period, a
  comma, or parentheses.

**Structure**

- One topic per paragraph. Cap a paragraph at six sentences.
- Write steps as a numbered vertical list. One action per item. Imperative form.
- A list item can be a label, not a sentence. Flow lists, changelogs, and
  feature bullets are labels. Keep a label in its short form ("Frontend
  receives session JWT"). Do not expand a label into a sentence only to give it
  an article. Decided 2026-08-04, after full-sentence conversion made flow
  lists harder to scan.
- Put the condition before the command. Write "If the log is empty, restart the
  job", not "Restart the job if the log is empty".

## Self-lint

Run this before you commit prose, post a comment, or return text.

1. Any instruction over 20 words, or any other sentence over 25? Split it.
2. Any semicolon or em dash? Replace it with a period.
3. Any contraction? Expand it.
4. Any passive voice with a known actor? Make it active.
5. Any "-ing" main verb, nominalization, or phrasal verb? Replace it with a
   plain verb.
6. Same thing named two ways? Pick one name.
7. Any label expanded into a sentence only to add an article? Make it a label
   again.

