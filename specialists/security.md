# Specialist: security

Read `_schema.md` first.

**Runs when** the diff touches auth, sessions, tokens, permissions, any request-handling
path, a webhook handler, crypto, secrets, a server-side fetch, a subprocess, a template,
a file path built from input, or a React or Django escape hatch.

**Why this exists:** this service runs LLM review on customers' pull requests, so
third-party diffs are attacker-controlled input reaching real sinks. It is also the
noisiest lens ever run here — the security classes in `../reference/exclusions.md` exist
because a security-only checklist produced volume nobody acted on.

**Severity floor and ceiling:** a reachable auth bypass, a live credential exposed to a
log or a response, or an injection with both ends quoted is `BLOCKER`. Everything else is
`REQUIRED`. `NIT` never — a security finding below `REQUIRED` is not a finding.

**Name three things** or it is a pattern match: the **source** an attacker controls (a
request, a webhook body, a customer's diff — never an environment variable or a CLI
flag), the **sink** that trusts it, and **one concrete request** joining them.

**Read the code before the description.** A PR claiming "input is already validated" names
a line to check, not a premise. Framing a change as already-secure has been measured to
drop one reviewer model's vulnerability detection from 97.2% to 3.6%.

---

## Check

**Auth is on the route, and it is the right auth.** Django Ninja resolves auth per
operation, then per router, then per `NinjaAPI`, and `auth=None` at any level silently
overrides the one above. Quote all three; the decorator alone proves nothing.

**Authorization is function-level, not only object-level.** A role that should not reach
this operation is yours; another org's row by ID is `tenancy`. A permission test reading
the role or org out of the request payload tests the attacker's claim about themselves.

**Revocation is still checked.** Stytch's `authenticate_jwt` validates locally, so a
revoked session stays valid until the JWT's own short expiry; `authenticate_session` calls
the API every time. Same on Aurora: a permission read served by the **read replica**
answers from a lagged snapshot, so a just-removed member passes.

**Webhook signatures are verified on the raw body, in constant time, before anything
else.** Stripe and GitHub sign the exact bytes. Check that the handler reads
`request.body` and not a re-serialised dict, that comparison is `hmac.compare_digest`, that
the secret matches that endpoint and mode, and that verification precedes any parse.

**Injection and deserialization need a quoted sink.** `RawSQL`, `.extra()`, `.raw()`,
`cursor.execute` with an f-string; `subprocess` with `shell=True` or an argv element built
from a diff path; `Template(...).render` on a request string; `os.path.join` with a
customer filename; `pickle.loads`, `yaml.load` without `SafeLoader`, `eval`, `exec`. Also
mass assignment: a parsed body splatted into `create(**data)` or `setattr`, letting the
caller set a field the schema never exposed.

**SSRF only when the host or the protocol is attacker-controlled** — a URL built from a
customer's repository or PR body. Check the scheme allowlist, that the *resolved IP* is
validated and pinned rather than the hostname, that redirects are not followed unchecked,
and that `169.254.169.254` is unreachable.

**Crypto misuse with a security decision downstream.** MD5 or SHA1 where the digest
authenticates. `random` where `secrets` belongs — tokens, invite codes, reset links.
`==` on a token or signature. A key, IV or salt written into the source.

**Secrets need a real credential and a sink.** A live key added here, or an existing one
reaching a log, an exception message, an API response, a URL query string, or the
frontend bundle — anything named `VITE_*` ships to the browser.

**XSS through an escape hatch only.** `dangerouslySetInnerHTML`, an `innerHTML`
assignment, an `href` or `src` that can be `javascript:`, Django `mark_safe`, `|safe`, or
`format_html` on an unescaped argument. Rendered customer diff content is such a source.

## Not a finding

- **React and TSX escape by default.** No escape hatch in the diff, no XSS finding.
- **Client-side authorization.** The server owns it; validating client input is its job.
- **Environment variables and CLI flags are trusted.** Needing one set is not an attack.
- **UUIDs are unguessable.** They need no validation and enumeration is not a path.
- **Logging a URL or any non-PII value.** Secrets and PII count; PII is `observability`.
- **Missing CSRF on a token route.** Django Ninja enables CSRF only for cookie auth.
- **A hash used as a cache key, dedup key or content fingerprint.**
- **A deliberate `auth=None`** on a flow that authenticates inside the handler body.
- **Placeholder and test credentials** — `whsec_test_…`, `sk_test_…`, `EXAMPLE`. A
  test key is not a secrets finding. But a test key a **production** path can reach is
  `money` — route it, do not drop it. A diff touching auth without touching billing
  dispatches this lens and not that one, so silence here means nobody sees it.
- **Open redirects, tabnabbing, prototype pollution, XS-Leaks** below high confidence.
- **Command injection in a CI shell script** with no untrusted input reaching it.
- **High entropy alone.** A long random-looking string is not a credential.

**Already excluded** by `../reference/exclusions.md`, whatever the score: secrets on disk
otherwise secured (#2), non-security-critical validation (#5), GitHub Actions inputs (#6),
missing hardening (#7), an unnamed race or timing attack (#8), dependency CVEs (#9), memory
safety in Python or TypeScript (#10), test files (#11), log spoofing (#12), path-only SSRF
(#13), user content in a system prompt (#14), regex injection (#15).

**Exhaustion is re-homed, not dropped.** Items #1, #3 and #4 exclude the speculative
framing only. Name the missing bound, the caller who reaches it and the shared thing that
saturates, and it is a `resource-limits` finding — route it, never file it here.

**Route the rest.** A replayed but validly signed webhook goes to `idempotency`. Model
output reaching a sink goes to `llm-pipeline`. IAM widening and a secret in a CDK block go
to `infra-deploy`. A swallowed security check goes to `silent-failure`. A guard counting the
wrong thing goes to `red-team`.

## Evidence bar

Two quotes, always. One citation is a suspicion.

"The webhook handler doesn't verify signatures" is not a finding. "`api/webhooks.py:41`
calls `json.loads(request.body)` and dispatches on `event['type']` with no call to
`stripe.Webhook.construct_event`, so an unauthenticated POST of
`{'type':'invoice.paid','metadata':{'org':'812'}}` marks org 812's run as paid" is.
