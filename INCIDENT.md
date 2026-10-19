# INCIDENT — notifications-worker won't stabilise in staging

**Reported by:** on-call (platform)
**Severity:** S2 — feature launch blocked
**Status:** open, handed over to you

## Summary

`notifications-worker` was deployed to staging yesterday using the Terraform in
`svc-notifications/`. The ECS service never reaches a steady state. The application
team has verified the container image locally (it boots, binds to port 8080 and
serves `GET /health` → 200) and `appointments-api` runs the same pattern in the
same cluster without problems.

## Observed symptoms

1. Tasks start, run for a short while, then get stopped and replaced — over and
   over. ECS service events show:
   `(service notifications-worker) (task ...) failed ELB health checks in (target-group notifications-worker)`.
2. On some deploy attempts tasks die much earlier, with stopped reason:
   `ResourceInitializationError: unable to pull secrets or registry auth ... secretsmanager:GetSecretValue`.
3. The CloudWatch log group `/ecs/notifications-worker` exists but is **empty** —
   we have no application logs at all, even for tasks that ran for ~1 minute.
4. The app team insists the JVM "needs a minute or so" before it answers health
   checks, but they claim that was "never a problem for other Java services".

## What on-call already ruled out

- Image is correct and healthy (ran locally and in a scratch cluster).
- The shared ALB, listener and cluster (from `core-infra`) serve other services fine.

## Ask

Find the root cause(s) in the infrastructure code, fix them, and write the RCA.
There is **more than one** independent problem.
