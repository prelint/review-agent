# Specialist: silent-failure

Read `_schema.md` first.

**Runs on every review.**

**Why this exists:** ported from Anthropic's `pr-review-toolkit`, the only library
examined that had a lens for it. A swallowed error is invisible in every other review
dimension — the code reads fine, the tests pass, and production quietly does nothing.

**Severity floor:** a swallowed failure on a write path, a payment path, or a security
check is `BLOCKER`. Elsewhere `REQUIRED`.

---

## Check

**Bare and broad excepts.** `except:`, `except Exception:`, `catch (e) {}`,
`catch { }`. For each, three questions: which exception was expected, what happens to
the unexpected ones, and does the caller learn anything?

**Caught and dropped.** The handler logs at debug, or increments nothing, or has a
comment saying "ignore" — and the operation the caller believed happened did not.

**`|| true` and `2>/dev/null`.** In shell, in CI steps, in Makefiles. Each one turns a
gate into decoration. Ask what the command was there to prevent, and whether the
suppression covers a known-benign case or everything.

**Default returns that mask absence.** `.get(k, {})`, `?? []`, `or None`, a fallback
object. Fine when absence is expected and handled; a defect when it lets a missing
value flow onward as an empty one. Trace where the default goes.

**Errors converted to falsy.** A function that returns `None`/`false`/`null` for both
"no result" and "failed", where the caller cannot distinguish them. Two different
outcomes collapsed into one value is a bug the caller cannot fix.

**Unawaited promises and fire-and-forget tasks.** A promise with no `await` and no
`.catch`, a background task whose exception goes nowhere, a thread whose failure is
never joined. The work silently does not happen.

**Retries that give up quietly.** A retry loop that exhausts and returns normally.
Someone must learn that the final attempt failed.

**Validation that only warns.** A check that logs and continues where it should
refuse. Especially on a security or tenancy boundary.

**Transactions that swallow rollback.** A caught exception inside a transaction block
where the rollback happens but the caller is told everything is fine.

**Empty handler bodies added in this diff** — including `pass`, `continue`, `return`,
and a lone comment.

---

## Not a finding

- A caught exception that is re-raised, returned as an error value, or converted to a
  typed failure the caller must handle.
- Suppression with a comment that names the specific expected condition and it is
  genuinely benign. Quote the comment and accept it.
- Cleanup and teardown paths where best-effort is correct — but say so, do not assume
  it.
- Test code deliberately suppressing noise.

## Evidence bar

Quote the handler and the call site that believes the operation succeeded. State what
the caller does next with the wrong belief.

"Broad except" alone is not a finding. "The `except Exception` at services.py:88
swallows the Stripe timeout, so `charge_org` returns normally and the caller marks
the run as billed with no ledger row" is.
