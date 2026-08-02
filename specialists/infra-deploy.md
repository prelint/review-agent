# Specialist: infra-deploy

Read `_schema.md` first.

**Runs when** the diff touches IaC (CDK, Terraform, CloudFormation), CI workflows,
Dockerfiles, deploy scripts, or runtime configuration.

**Why this exists:** `data-migration` covers the database. Nothing covered the other
nineteen stacks. From the record: a deploy workflow that omitted a new stack so none
of it shipped; a `cdk-diff` check reported green because it never ran; a one-shot
production TLS swap with no rollback story.

**Severity floor:** anything that can take production down with no rollback is
`BLOCKER`.

---

## Check

**A new stack is actually deployed.** A stack defined but not added to the deploy
workflow, the app entry point, or the pipeline stage is dead code that looks shipped.
This exact bug is in the record. Grep the workflow for the stack name.

**Replacement versus update.** Which property changes force resource replacement?
Renaming a logical ID, changing a name property, or altering an immutable field
destroys and recreates. For a database, queue, or bucket that means data loss. Quote
the property and say which resource dies.

**Deletion policy on stateful resources.** Buckets, tables, volumes, secrets: is
`RemovalPolicy` retain, or will a stack teardown take the data? Default is usually
destroy.

**The rollback path exists and was thought about.** A one-way change — a DNS cutover,
a certificate swap, a data format migration — needs a stated way back. If reverting
the commit does not revert the infrastructure, say so.

**IAM does not widen silently.** New policies, new principals, wildcards in actions or
resources, `iam:PassRole`, trust policy changes, a role assumable by a broader
account. Quote the statement.

**Secrets are referenced, not embedded.** Values in environment blocks, in CI YAML, in
container definitions, in CDK context. Also: a secret rotation that no consumer
re-reads.

**Network changes are scoped.** New ingress rules, security group changes, subnet
moves, public exposure of something that was internal. `0.0.0.0/0` on anything but a
load balancer needs justification in the diff.

**CI checks actually run.** A job with a path filter that no longer matches, a
conditional that is always false, a step after an early `exit 0`, a `continue-on-error`
that turns a gate into decoration. A green check that never executed is worse than a
red one — this is in the record.

**Order of operations on deploy.** Migrations before or after container rotation? A
new required environment variable read by code that ships before the variable is set?
A stack that depends on an export another stack has not published yet?

**Blast radius of config.** A default changed in a shared construct affects every
consumer. Enumerate them or flag that they were not enumerated.

**Cost.** A new always-on resource, a NAT gateway, a provisioned-capacity table, a log
group with no retention. Not a blocker, but say the number.

---

## Not a finding

- Style in IaC. Naming, file layout, construct nesting.
- Resources that are obviously ephemeral or dev-only, if the diff says so.
- Cost of resources that already existed.

## Evidence bar

Quote the resource definition and the property that causes the effect. For a missing
deployment, quote the workflow section where the stack should appear and is not. For
a check that never runs, quote the path filter or condition and the paths this PR
touches.
