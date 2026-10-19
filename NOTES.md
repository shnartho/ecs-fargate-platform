# Notes

## Part 1 design decisions

### Where the module lives
- The module is in `terraform-aws-fargate-service/`.
- It sits at the top level. It acts like its own repo.
- Services use it by a local path here.
- In production they pin a git tag: `git::https://github.com/<org>/terraform-aws-fargate-service.git?ref=v1.0.0`.

### Interface
The goal is simple. Make mistakes impossible.
- One `container_port` drives the container, target group and security group rule. They cannot disagree.
- The log region comes from `data.aws_region`. It is not an input.
- `secrets` is a map of env var to Secrets Manager ARN. The module grants `GetSecretValue` on exactly those ARNs.
- `health_check_grace_period_seconds` is required with no default. Each team must state its startup time.
- Validation rejects bad input at plan time. Examples: Fargate CPU values, target group name length, ARN format.
- Circuit breaker with rollback is always on. It is not configurable.

### Cross-repo wiring
- Each service reads core-infra state once, in `core_infra.tf`.
- It passes plain values into the module.
- The module never reads remote state. It is backend agnostic and testable in isolation.
- Core-infra outputs are now a public contract. Renaming one is a breaking change for every service.

### Safe adoption
- `moved` blocks map old addresses into the module. Live resources are not recreated.
- Both services are aligned: AWS provider `~> 5.0`, `Environment` and `Service` tags, circuit breaker. Notifications was on `~> 4.0`.

### Left out on purpose
- No autoscaling, sidecars, multiple containers or service discovery.
- They get added when a second service needs them. Not before.
- No `enable_x` flags. Each flag doubles the combinations to support and test.

## Part 3 answers

### 1. Versioning and distribution
**Choice:** one repo per module, semver git tags, a private registry once there are several modules.
- The module lives in its own repo: `terraform-aws-fargate-service`.
- Releases are semver tags like `v1.4.2`. Patch is a fix. Minor adds an optional input. Major is breaking.
- CI cuts the tag from conventional commits, for example with release-please. The changelog is generated.
- Tags are protected. A released tag is never moved.
- Services pin a version. With git: `?ref=v1.4.2`. With a registry: `version = "~> 1.4"`.
- Start with git tags. Move to a private registry (HCP Terraform, GitLab or Artifactory) as the module count grows. Git refs only allow exact pins. A registry adds version constraints, discovery and docs.

**Why not a monorepo**
- Service repos are already separate. Teams own their release cadence.
- A monorepo with unpinned modules makes every module change hit every service on its next plan. One bad merge breaks the fleet.
- Pinned versions let each team upgrade on its own schedule. The platform team still sees who runs what.

**Supporting pieces**
- Module CI runs `fmt`, `validate`, `tflint` and `terraform test` with mock providers. It also plans an example service on every PR.
- Renovate watches every service repo. It opens an upgrade PR when a new module version ships. The PR shows the plan.
- A version inventory shows which repo runs which module version.

### 2. Rolling out a breaking change
**Principle:** no flag day. Teams on the old version keep shipping. The upgrade is small, boring and has a deadline.
1. **Avoid the break if possible.** Add the new input next to the old one. Deprecate the old one with a `check` block warning. Ship it as a minor release.
2. **If it must break, release `v2.0.0`.** `v1` stays supported on a `v1.x` branch. Security and critical fixes are backported for a fixed window, for example 90 days.
3. **Make state migration automatic.** Ship `moved` blocks inside the module. The upgrade plan should show zero destroys. If a replacement is unavoidable, document a zero downtime path.
4. **Write an upgrade guide.** Exact input changes. A before and after example. The expected plan output.
5. **Pilot first.** The platform team upgrades one low-risk service itself. Then one service per stack, Node.js and JVM. Fix the guide with what was learned.
6. **Roll out in waves.** Renovate opens upgrade PRs in every repo. Teams merge in their normal flow. PRs with a zero destroy plan are fast-tracked.
7. **Guard the rollout.** CI blocks any plan that destroys a stateful or networking resource without an explicit approval.
8. **Track and close.** A dashboard shows repos per major version. Announce the `v1` end of support date early. Pair with teams that are stuck. After the date, CI warns on `v1`. Later it blocks new `v1` usage.

## Stretch: CI
`.github/workflows/terraform.yml` runs on every PR and on `main`.
- **Static job.** `fmt -check`, module `validate`, `tflint` with the recommended preset, and a guard that fails on hardcoded `vpc-`, `subnet-` or `sg-` IDs in service repos.
- **Plan job.** One matrix leg per service. It runs `init`, `validate` and `plan`, then writes the plan to the job summary.
- No AWS credentials are needed. The offline provider block makes `plan` work in CI.
- The hardcoded ID guard is one of the RCA guardrails, implemented for real.
- Validating the module found a real issue. It allowed AWS provider 6.x, which it was never tested on. It is now capped at `>= 5.0, < 6.0`.

In a real setup, each service repo calls one reusable workflow owned by the platform team.

## Flagged beyond the brief
- **Migration risks.** The notifications execution role is renamed from `-exec-role` to `-task-execution-role`, so it is replaced. Security group rules move from inline blocks to standalone resources. The old inline `3000` rule becomes unmanaged and must be removed by hand. Review the real plan before applying.
- **Listener priorities.** `110` and `120` are hand-picked per repo. They will collide as services grow. Options: a priority registry in core-infra, or host-based routing per service.
- **Remote state exposure.** Every service can read the full core-infra state, including any secrets in it. In production, publish outputs to SSM Parameter Store instead.
- **Open egress.** Every service allows `0.0.0.0/0` outbound. Narrow it with VPC endpoints for ECR, Secrets Manager and CloudWatch Logs.
- **State file in git.** Acceptable for the exercise. In production, state lives in S3 with locking and encryption.
- **Module docs.** Generate the module README with `terraform-docs` so it never drifts from the code.

## Cut for time
- **Module tests.** `terraform test` with mock providers for the precondition and the secret IAM wiring.
- **Policy rules.** The RCA names conftest rules. They are not written yet.
- **Container health check.** An ECS container health check with a `startPeriod` would give a second startup signal next to the ALB.
- **CI hardening.** Pin actions to commit SHAs. Post the plan as a PR comment. Add the tflint AWS ruleset.
