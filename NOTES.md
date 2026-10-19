# Notes

## Part 1 — Design decisions

**Where the module lives**
- `terraform-aws-fargate-service/` is a top-level directory, simulating its own repo like the others.
- Service repos consume it by relative path here; in production it is pinned to a git tag
  (`git::https://github.com/<org>/terraform-aws-fargate-service.git?ref=v1.0.0`).

**Interface: make the wrong thing impossible, not just discouraged**
- One `container_port` drives the container port mapping, target group and security group rule — the
  three can no longer disagree.
- The log region comes from the provider (`data.aws_region`), not an input — logs cannot be sent to a
  different region than the service.
- `secrets` is a map of env var → Secrets Manager ARN; the module grants the execution role
  `GetSecretValue` on exactly those ARNs — declaring a secret and its permission can't drift apart.
- `health_check_grace_period_seconds` is required with no default — every team has to state their
  startup time instead of inheriting a value tuned for someone else's app.
- Input validation catches bad values at plan time (Fargate CPU values, name length for the target
  group limit, priority range, ARN format, health-check timeout < interval).
- Deployment circuit breaker with rollback is always on; not configurable.

**Cross-repo wiring**
- Each service reads `core-infra` state once (`core_infra.tf`) and passes plain values into the module.
- The module never reads remote state itself, so it doesn't care where `core-infra` lives or which backend
  it uses — it's testable and reusable outside this setup.
- `core-infra`'s outputs are now a public contract: renaming one is a breaking change for every service.

**Safe adoption**
- `moved` blocks map the old resource addresses into the module, so adopting it doesn't destroy and
  recreate live resources.
- Both services aligned on the same provider version (`~> 5.0`; notifications was on `~> 4.0`), tag keys
  (`Environment`, `Service`) and circuit breaker.

**Deliberately left out of the module**
- Autoscaling, sidecars, multiple containers, non-ALB services, service discovery. Add them when a second
  service actually needs them, not before.
- No `enable_x` feature flags — they multiply the combinations the module must support.

## Flagged beyond the brief / would do next

- **Migration caveats for real environments**: notifications' execution role is renamed to the standard
  name (`-exec-role` → `-task-execution-role`), which replaces it. Security group rules move from inline
  blocks to standalone resources, so the old inline rule (port 3000) is no longer managed and would have
  to be removed by hand. Both need checking against the real plan before applying.
- **Listener priorities** (110, 120) are hand-picked per repo and will collide as services grow. Options:
  a registry of priorities in `core-infra`, or host-based routing per service.
- **Remote state exposes the whole `core-infra` state** to every service (including any secrets in it).
  In production I'd publish the outputs to SSM Parameter Store, or give services read-only access to
  just the state object.
- **Egress is open to `0.0.0.0/0`** on every service. Should be narrowed (VPC endpoints for ECR, Secrets
  Manager and CloudWatch Logs; NAT only where needed).
- **Committed state file**: fine for the exercise; in production state lives in S3 with locking and
  encryption, never in git.
- **Module README** generated with `terraform-docs` so the interface docs stay in sync with the code.
