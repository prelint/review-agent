# Specialist: testing

Read `_schema.md` first.

**Runs when** the diff adds or edits a test, changes test configuration, or adds a
behaviour branch.

**Why this exists:** nothing ever read the tests a diff contains — `backend/tests`
holds 1,927 mock-call assertions across 333 files, and a lens counting only absent
tests never opens one. `../reference/exclusions.md` #21 bans missing coverage as a
standalone finding, so absence had no owner either.

**One missing-test finding per review.** The binding constraint on this file. Say a
behaviour is untested once, naming the behaviour, the input that reaches it, and the
wrong outcome nobody would see. Spend it on a branch whose failure is silent and
expensive — a permission denial, a tenant filter, a refund, a retry cap. A coverage
percentage or a per-function sweep dies in Stage 3 and was the noise. Reviewing tests
that **exist** carries no cap: a test that cannot fail is a defect like any other.

**Severity:** `REQUIRED` for a test in this diff that cannot fail, and for an
assertion loosened with no stated reason. `BLOCKER` only when the weakened guard
covers money, tenancy or auth and the behaviour it stopped covering is live; flakes
are `NIT`. A missing-test finding inherits the severity of the behaviour it leaves
unguarded, never more.

---

## Check

**Would this test fail against the pre-change code, and fail for the right reason?**
The master question. Revert the source hunk in your head and ask what goes red. If
nothing does, the test guards nothing — and unlike missing coverage, you can quote
it. The failure must also be **behavioural, not structural**: an `ImportError`, a
collection error or an `AttributeError` proves the surface is absent, never that the
assertion rejects a wrong answer.

**Assertions that cannot discriminate.** Three shapes. *Tautological* — the expected
value comes out of the code under test, so `assert total == compute_total(items)`
agrees with the implementation including when it is wrong. *Weak* — `is not None`,
`len(...) > 0`, `status_code != 500`, a bare `toMatchSnapshot()`; each passes for a
large set of wrong values, so name one it accepts. *Unreachable* — an `expect` in a
callback nothing invokes, or an assertion after an early `return`.

**Mocks stand in for collaborators, never for the unit.** Patching the function under
test, or asserting a value the same test told a mock to return, tests the mock.
`assert_called_once_with` is a finding only when it is the *only* assertion about a
behaviour this diff introduced and the real outcome is observable — a row written, a
response body, a rendered string. It is dense and mostly legitimate here.

**A loosened assertion in this diff is the finding.** A deleted `assert`, a widened
tolerance or timeout, a fuzzier matcher, a `skip`/`xfail`/`it.skip`, a rename the
runner no longer collects, a regenerated snapshot. Only three justifications hold:
the requirement changed, the old test was wrong, the new behaviour is intended. If
the description states none, the test was edited to make CI green. `backend/tests`
has zero skip marks today, so one added here is deliberate.

**The runner collects the file.** `pyproject.toml:85` sets `python_files =
["test_*.py"]`; `frontend/vitest.config.ts:27` sets
`include: ['tests/**/*.test.{ts,tsx}']`. A new `foo_test.py`, or a spec beside its
component under `src/`, never runs. Quote the config and the new path.

**The environment can produce the failure.** `transaction.on_commit` callbacks do not
fire under pytest-django's default database fixture, so an effect scheduled there
needs `django_capture_on_commit_callbacks` — used 116 times here — or
`transaction=True`. The `readonly` alias exists only where `DB_READER_HOST` is set,
so `config/db_router.py` falls through to `default` in every test: **no test can
exercise replica routing or read-after-write staleness.**

**Flakes carry a named schedule.** `addopts` has `-n auto`, so tests run in separate
processes in an order nothing fixes — module-level state, a mutated class attribute,
a reused `QueryClient` cache or a shared external resource is a real flake here. Same
bar for real `now()` where `freeze_time` exists, `time.sleep`, a tight `waitFor`,
unseeded data, or an assertion on unordered results. Name the pair of tests or the
input that flips it.

---

## Not a finding

- Missing tests as a count, a percentage, or a list. Exclusion #21.
- A second missing-test finding. Keep the worst, drop the rest.
- `assert_called_once_with` where the collaborator call **is** the contract — an
  enqueued task, a provider request, a webhook post.
- Test style: naming, layout, `parametrize` versus a loop, fixture placement.
- Coverage that exists elsewhere. Grep before claiming absence, using the globs above.
- Security defects inside fixtures and attack corpora. Exclusion #11 — those files
  exist so the guards that block them can be verified.
- Out of scope, by owner: a missing eval case for a prompt change is `llm-pipeline`;
  a description claiming coverage the diff lacks is `spec-drift`; a CI job that never
  runs is `infra-deploy`; a test outside the diff this change leaves wrong is
  `coherence`.

## Evidence bar

Quote the test and the production line it covers, then say what you would break to
turn it red. If the answer is "nothing", that sentence is the finding.

"This test is weak" is not a finding. "`tests/billing/test_credits.py:88` asserts
only `charge_mock.assert_called_once()`, so flipping `services.py:212` from
`math.floor` to `round` keeps it green and overcharges every run by a cent" is.
