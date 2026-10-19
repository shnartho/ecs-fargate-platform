# RCA: notifications-worker failed to stabilise in staging

**Severity:** S2. Feature launch blocked.
**Scope:** Staging only. No customer impact.
**Status:** Fixed in code. Pending redeploy to staging.

## Symptoms
1. Tasks were replaced in a loop. ECS reported `failed ELB health checks in (target-group notifications-worker)`.
2. Some deploys failed before the app started. ECS reported `ResourceInitializationError: unable to pull secrets or registry auth`.
3. The log group `/ecs/notifications-worker` stayed empty. This held even for tasks that ran about a minute.
4. No circuit breaker stopped the loop or rolled back.

## Root causes
`svc-notifications` was copied from `svc-appointments` and edited by hand.
Five independent defects shipped together.

| # | Defect | Effect | Symptom |
|---|---|---|---|
| 1 | Task security group allowed the ALB on `3000`. Container and target group use `8080`. | ALB health checks could never reach the app. | 1 |
| 2 | Grace period was `10s`. Health check ran every `10s` and failed after `2` misses. | Tasks were killed after about 30s. The JVM needs 60 to 90s. | 1 |
| 3 | Execution role had no `secretsmanager:GetSecretValue` on `notifications/smtp-creds`. Its only extra policy re-granted log permissions it already had. | ECS could not inject `SMTP_CREDENTIALS`. | 2 |
| 4 | Service used `subnet-0bbb7777aaaa8888d`. It is not in core-infra `private_subnet_ids`. | Tasks placed there likely had no route to Secrets Manager or ECR. | 2 |
| 5 | `awslogs-region` was `us-east-1`. Service and log group are in `eu-central-1`. | Logs never reached the expected log group. | 3 |

### Contributing factors
- No deployment circuit breaker. `svc-appointments` had one. `svc-notifications` did not.
- Shared values were hardcoded in each repo. The copies drifted. They were even on different AWS provider major versions.
- No CI gate. Nothing validated the Terraform before staging.

### Open question
Defect 3 alone fails every task. Yet only some deploys failed this way.
That pattern fits defect 4, which depends on task placement.
To confirm, compare the subnet of stopped tasks with `AccessDenied` events for `GetSecretValue` in CloudTrail.
Both defects are fixed regardless.

## Fix
The service now uses the shared `terraform-aws-fargate-service` module.
1. One `container_port` input drives the container, target group and security group rule.
2. Grace period is `150s`. That is the 90s worst case plus headroom. Health checks use module defaults: every `30s`, unhealthy after `3` misses.
3. The module grants `GetSecretValue` on exactly the secret ARNs the service declares.
4. Subnets come from core-infra state via `terraform_remote_state`.
5. Log region comes from the provider. It is no longer an input.

Circuit breaker with rollback is now always on.

## Prevention
| Class of issue | Guardrail | Stage |
|---|---|---|
| Port mismatch | Single `container_port` input in the module. OPA/conftest rule on plan JSON as backstop. | Design, PR |
| Startup timing | Grace period is a required input with no default. Module precondition rejects values below `interval` times `healthy_threshold`. This is a floor, not a full check. A post-deploy smoke test in staging gates promotion. | Design, plan, deploy |
| Missing secret IAM | Module derives IAM from declared secrets. Conftest rule: every secret ARN must be covered by the execution role. | Design, PR |
| Hardcoded IDs | Shared values come from core-infra outputs. tflint or conftest rule rejects literal `vpc-`, `subnet-` and `sg-` IDs. | PR |
| Region drift | Region comes from the provider. Conftest rule: `awslogs-region` must equal the provider region. | Design, PR |
| Silent loop | Circuit breaker on by default. Alarms on `SERVICE_DEPLOYMENT_FAILED` events and on zero log events after a deploy. | Runtime |
| Copy-paste drift | One versioned module. CI on every service repo runs `fmt`, `validate`, `tflint`, policy checks and posts `plan` to the PR. | PR |

