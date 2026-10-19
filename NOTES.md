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

## Flagged beyond the brief
- **Migration risks.** The notifications execution role is renamed from `-exec-role` to `-task-execution-role`, so it is replaced. Security group rules move from inline blocks to standalone resources. The old inline `3000` rule becomes unmanaged and must be removed by hand. Review the real plan before applying.
- **Listener priorities.** `110` and `120` are hand-picked per repo. They will collide as services grow. Options: a priority registry in core-infra, or host-based routing per service.
- **Remote state exposure.** Every service can read the full core-infra state, including any secrets in it. In production, publish outputs to SSM Parameter Store instead.
- **Open egress.** Every service allows `0.0.0.0/0` outbound. Narrow it with VPC endpoints for ECR, Secrets Manager and CloudWatch Logs.
- **State file in git.** Acceptable for the exercise. In production, state lives in S3 with locking and encryption.
- **Module docs.** Generate the module README with `terraform-docs` so it never drifts from the code.
