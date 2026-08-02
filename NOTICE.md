# Attributions

This skill borrows ideas, checklists and prompt text from the projects below. All the
open-source ones are permissively licensed and compatible with each other and with
private use. Attribution here satisfies the MIT notice requirement and the Apache-2.0
attribution requirement in one place.

| Source | License | Holder | What was taken |
|---|---|---|---|
| [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) — `code-review`, `pr-review-toolkit` | Apache-2.0 | Anthropic | The 0–100 scoring rubric and its separate-scorer design, the pre-post eligibility re-check, the false-positive catalog, `silent-failure-hunter`'s checklist |
| [obra/superpowers](https://github.com/obra/superpowers) | MIT | Jesse Vincent (2025) | `receiving-code-review`: source-agnostic feedback handling, verify-before-implementing, clarify-all-before-implementing-any, reply in thread |
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | MIT | Addy Osmani (2025) | Severity prefixes, structural remedies, "one structural problem and ten nits means the structural problem is the review", and the likelihood axis (issue #436 / PR #441) |
| [mattpocock/skills](https://github.com/mattpocock/skills) | MIT | Matt Pocock (2026) | Two-axis Standards/Spec separation with no cross-axis reranking, word caps in the subagent brief, the Necessity axis (issue #713) |
| [garrytan/gstack](https://github.com/garrytan/gstack) | MIT | Garry Tan (2026) | The quote-or-drop verification gate, the specialist taxonomies, the `red-team` lens |

## Apache-2.0 obligations

`code-review` and `pr-review-toolkit` are Apache-2.0, which additionally requires that
modifications be stated. They are: our scoring rubric keeps Anthropic's 0/25/50/75/100
band definitions verbatim but raises the threshold behaviour, adds a quote-or-drop
filter ahead of it and a likelihood filter after it. `silent-failure-hunter` was
rewritten to our specialist schema with a "not a finding" section added.
