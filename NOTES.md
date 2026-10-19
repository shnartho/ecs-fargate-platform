# Notes

## Part 1 design decisions

- The top-level Fargate module acts as a separate repo. Both services use a local source for this exercise.
- Each service reads core-infra state and passes plain values into the module. The module stays backend agnostic.
- One `container_port` drives the container, target group and security-group rule.
- Log region comes from the provider. Secret inputs generate permissions for exactly those ARNs.
- Grace is required. Notifications uses 150s for reported 60-90s startup plus health-check headroom.
- Removed the earlier grace-period precondition. ALB thresholds do not measure application startup. Service owners must verify readiness in staging.
- CPU/memory pairs and whole secret ARNs are validated. Circuit breaker and rollback are always enabled.
- Service creation waits for the listener and execution-role policies. IAM propagation can still take time.
- No autoscaling, sidecars or multi-container options. Add them when a real consumer needs them.

### Migration
- Keep `moved` blocks for resource-address changes. Preserve notifications' existing execution-role name with `execution_role_name`.
- Keep security-group rules inline. Terraform can replace port 3000 with 8080 without leaving the old rule unmanaged or creating duplicate standalone rules.
- Expect new task-definition revisions and service rollouts. Remove notifications' redundant logging policy while retaining the managed execution policy.
- Before applying, review a saved plan against the existing service state. Check notifications' AWS provider upgrade from 4.x to 5.x too. Fresh-state plans do not prove migration safety.

## Part 3 answers

### 1. Versioning and distribution
**Recommendation:** one module repo with protected semver tags. Move to a private registry when discovery and version constraints become useful.
- Pin Git sources, for example `git::https://github.com/<org>/terraform-aws-fargate-service.git?ref=v1.4.2`. Never move a released tag.
- Use patch releases for compatible fixes, minor releases for compatible additions and major releases for breaking changes.
- Independent versions fit the existing service repos. Teams can upgrade without sharing a release schedule.
- Use release-please for releases and Renovate for upgrade PRs. Keep a simple repo-to-version inventory.

### 2. Rolling out a breaking change
**Recommendation:** no flag day. Teams on the old major keep shipping.
1. Prefer an additive change with deprecation before a breaking release.
2. Release `v2` alongside `v1`. Backport critical fixes for an announced window, such as 90 days.
3. Provide an upgrade guide, `moved` blocks and expected plan changes. Document any required imports or replacements.
4. Pilot one low-risk service, then cover both Node.js and JVM workloads. Verify health and rollback before expanding.
5. Open upgrade PRs in waves. Require review of destructive changes. Teams merge within their own release schedules.
6. Track versions, help blocked teams and retire `v1` after the support window.

## Stretch: CI
**Implemented:** the [workflow](.github/workflows/terraform.yml) runs fmt, validate, tflint, mock tests and a literal network-ID guard. Both service plans appear in the job summary. It needs no AWS credentials.

Six test runs cover port consistency, logging, scoped secrets, rollback, subnet wiring, role names, grace settings and invalid inputs. Terraform >= 1.7 is required for mock tests. Module usage remains >= 1.5. CI uses 1.8.5.

## Local verification
Initialize providers once before working offline. Run from the workspace root:

```powershell
terraform fmt -check -recursive
terraform -chdir=terraform-aws-fargate-service init -backend=false -input=false
terraform -chdir=terraform-aws-fargate-service validate
terraform -chdir=terraform-aws-fargate-service test -no-color
terraform -chdir=svc-appointments init -input=false
terraform -chdir=svc-appointments validate
terraform -chdir=svc-appointments plan -input=false
terraform -chdir=svc-notifications init -input=false
terraform -chdir=svc-notifications validate
terraform -chdir=svc-notifications plan -input=false
```

Local checks passed. Both plans show **10 to add, 0 to change, 0 to destroy**. Hosted CI passed on the previous push. The contract tests run there on the next push. Nothing was applied to AWS.

## Flagged beyond the brief
- **Listener priorities.** `110` and `120` are hand-picked per repo. They will collide as services grow. Core-infra owners should allocate them.
- **Remote state exposure.** Every service can read the full core-infra state. Publishing shared outputs through SSM would limit that. Production state belongs in encrypted remote storage with locking.
- **Open egress.** Every service allows all outbound traffic. Review dependencies before restricting it. Account for AWS endpoints and ECR's S3 image-layer access.
- **Secret scope.** Secret selectors and customer-managed KMS keys are outside this module's current scope. KMS needs both decrypt permission and key-policy access.

## Cut for time
- Verify live migration and incident recovery using real service state and a staging deployment.
- Add promotion smoke tests, deployment-failure alerts and missing-log alerts. Add broader policy checks when needed.
- Pin CI actions to commit SHAs and add the tflint AWS ruleset. Use a shared workflow across real service repos.
