# Never report

A blocklist applied after scoring. Anything matching drops regardless of confidence.

The first fifteen started from a security-only exclusion list. The rest come from what
actually wasted time in the logs.

**Items 1, 3 and 4 are narrowed.** They suit a lens whose only job is finding
exploitable vulnerabilities, where resource exhaustion is out of scope by definition
and generates enormous false-positive volume. That reasoning does not survive the move to a general review of a metered multi-tenant service: a missing
bound here degrades other tenants and bills the customer, and this codebase has already
shipped an ingestion run that cost $642 unchecked. What stays excluded is the
*speculative framing* that generated the volume, not the defect class.

## Security classes that are not findings

1. **Speculative denial-of-service framing.** "An attacker could send many requests",
   "this loop could be made large", "this input is unbounded" — applied to a path
   where you cannot say what saturates or who is affected. Almost any loop can be
   described this way, which is why it is excluded.
   **Not excluded:** a specific missing bound with a named blast radius. That is a
   finding and it belongs to `resource-limits`. See below.
2. **Secrets on disk** that are otherwise secured. Handled by other processes.
3. **"Add rate limiting" as general advice.** Excluded when it names no endpoint, no
   caller, and no consequence. A missing limit on a *specific* path that a specific
   caller can reach is `resource-limits` work, not an exclusion.
4. **Memory or CPU exhaustion as a security finding.** It is not a confidentiality or
   integrity breach. Where it degrades service for other tenants or breaches a cost
   ceiling, it is a `resource-limits` or `money` finding — route it there rather than
   dropping it.
5. **Missing input validation on non-security-critical fields** with no proven
   security impact.
6. **GitHub Action workflow input sanitisation**, unless clearly triggerable by
   untrusted input.
7. **Missing hardening.** Code is not expected to implement every best practice.
   Flag concrete vulnerabilities, not absent defence-in-depth.
8. **Race conditions or timing attacks with no named interleaving.** If you can name
   the schedule, it is a finding — file it with the `likelihood` band it deserves and
   let Filter 3 downgrade it. Only the unnamed "there could be a race here" is
   excluded.
9. **Outdated third-party libraries.** Managed separately.
10. **Memory safety** — buffer overflows, use-after-free — in memory-safe languages.
11. **Test-only files**, fixtures, and anything under a `test/`, `*.test.*`,
    `*.spec.*`, or `*fixture*` path. A project's own attack-pattern corpus exists so
    the guards that block it can be verified.
12. **Log spoofing.** Unsanitised user input in logs is not a vulnerability.
13. **SSRF that controls only the path.** SSRF matters when it controls host or
    protocol.
14. **User-controlled content in an LLM system prompt.** Not by itself a
    vulnerability — see the `llm-pipeline` specialist for what actually is.
15. **Regex injection.** Untrusted content in a regex is not a vulnerability.

## General classes that are not findings

16. **Pre-existing issues.** If the line is not in this diff, it is not this PR's
    problem. Note it in the summary at most once, as FYI, and only if severe.
17. **Anything a linter, formatter, type checker, or compiler catches.** Missing
    imports, type errors, formatting, unused variables, trailing newlines. CI runs
    separately. Do not run the build to find these.
18. **Pedantic nitpicks a senior engineer would not raise.**
19. **Issues silenced in code on purpose** — a lint-ignore, a `# noqa`, a documented
    suppression.
20. **Intentional changes related to the broader change.** Not every deviation is a
    defect.
21. **Missing test coverage as a standalone finding.** Say it once, in the `testing`
    specialist's voice, tied to a specific untested behaviour. Never as a general
    complaint.
22. **General code quality, documentation, or security posture** without a concrete
    instance. "Consider adding more validation" is not a finding.

## Process classes that are not findings

23. **Anything the diff already fixes.** Read the whole diff first. This was the most
    common wasted finding in the logs.
24. **Advisory cross-references** — stale docs, unclosed TODOs, queue position,
    changelog gaps. These generated informational volume and nobody acted on them.
    If a doc is genuinely wrong *because of this diff*, that is a `spec-drift`
    finding with a quoted line. Otherwise, silence.
25. **"Positive observations."** Never write a strengths section. A review that lists
    what is good to soften what is bad wastes the reader's attention.
26. **Anything you cannot quote.** If Stage 3's quote filter dropped it, it does not
    come back as a "consideration" in the summary.

## The volume rule

If everything you found falls in this file, **post nothing**. Update the ledger, push
the fixes if any, and stop. A clean PR does not need an announcement.
