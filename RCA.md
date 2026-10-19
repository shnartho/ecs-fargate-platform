# RCA: notifications-worker failed to stabilise in staging

**Severity:** S2. Feature launch blocked.
**Scope:** Staging only. No customer impact.
**Status:** Fixed in code. Recovery needs staging verification.

## Symptoms
1. Tasks repeatedly failed ELB health checks and were replaced.
2. Some tasks stopped with `ResourceInitializationError: unable to pull secrets or registry auth ... secretsmanager:GetSecretValue`.
3. The log group `/ecs/notifications-worker` stayed empty.
4. Nothing stopped the loop or rolled the deploy back.

## Root causes
`svc-notifications` was copied from `svc-appointments` and edited by hand. The original configuration had five defects.

| # | Defect | Effect | Symptom |
|---|---|---|---|
| 1 | Task ingress allowed the ALB on `3000`. Container and target group use `8080`. | ALB health checks could never reach the app. | 1 |
| 2 | Grace was `10s`. Checks ran every `10s` and marked a target unhealthy after `2` failures. The JVM needs 60 to 90s. | Tasks were replaced before the app was ready. | 1 |
| 3 | Execution role had no `secretsmanager:GetSecretValue` on `notifications/smtp-creds`. | ECS could not inject `SMTP_CREDENTIALS`. | 2 |
| 4 | Service used `subnet-0bbb7777aaaa8888d`. It is not in core-infra `private_subnet_ids`. | Tasks there may have no route to Secrets Manager or ECR. Needs confirmation. | 2 |
| 5 | `awslogs-region` was `us-east-1`. Service and log group are in `eu-central-1`. | Logs went to the wrong region. | 3 |

**Contributors:** copy-paste drift, hardcoded shared values, no CI and no circuit breaker on notifications.

**Open question:** defect 3 should fail every task, yet some tasks ran for about a minute. The likely explanation is that deploy attempts used different task definition revisions. To confirm, compare the revision and subnet of stopped tasks with `AccessDenied` events in CloudTrail.

## Fix
1. One `container_port` drives the container, target group and security group rule.
2. Grace is `150s`. Checks run every `30s` and mark a target unhealthy after `3` failures.
3. The module grants `GetSecretValue` on exactly the declared secret ARNs. Policies attach before the service is created.
4. Subnets come from core-infra state.
5. Log region comes from the provider.
6. Circuit breaker and rollback are always on. Rollback needs a previous completed deployment.

## Prevention
| Class | Guardrail | Status |
|---|---|---|
| Port mismatch | Single port input + contract test | Implemented |
| Missing secret IAM | Permissions generated from declared secrets + contract test | Implemented |
| Region drift | Region derived from the provider + contract test | Implemented |
| Hardcoded network IDs | Core-infra state + CI literal-ID guard | Implemented |
| Startup timing | Required grace input with no default. Readiness gate in staging. | Input implemented, gate next |
| Repeated failures | Circuit breaker + contract test | Implemented |
| Copy-paste drift | Shared module + CI fmt, validate, tflint, tests and plans | Implemented |
| Silent failures | Alerts on deployment failure and empty log groups | Next |

Before closure, the service owner and on-call verify steady state, healthy targets, `/health`, secret initialization and log delivery in staging.

