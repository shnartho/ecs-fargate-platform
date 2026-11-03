# Platform Engineering Assignment

Welcome! This exercise is modelled closely to a microservices architecture 
on **ECS Fargate**, **one Terraform repo per service**, plus shared foundational repos
(`core-infra`) that service repos depend on. Everything here runs **fully offline** —
you do **not** need an AWS account.

## Time box

**3–4 hours maximum.** We mean it. If you run out of time, stop and write down what
you would do next in `NOTES.md` — prioritisation under a time budget is part of what
we assess.

AI assistants are allowed. In the debrief you'll walk us through your decisions, so
make sure every line is one you can defend.

## Repo layout

Each top-level directory simulates a **separate Git repo**:

```
core-infra/          shared VPC / ALB / ECS cluster (stubbed; committed local state)
svc-appointments/    appointments-api  — Node.js, listens on :8080, GET /health, ~10s startup
svc-notifications/   notifications-worker — Java/Spring Boot, listens on :8080, GET /health, 60–90s startup (JVM warm-up)
INCIDENT.md          on-call report for Part 2
```

`core-infra` is stubbed for the exercise, but its **outputs and local state file are
real** — consume them the way you would in production.

## How to run (offline)

Requires Terraform >= 1.5. `terraform init` needs internet once (provider download);
after that everything works offline thanks to the pre-configured provider block
(fake credentials + `skip_*` flags — please don't remove it).

```
cd svc-appointments && terraform init && terraform plan
```

A clean `terraform plan` in both service repos is the acceptance gate for Part 1.

## Part 1 — Refactor (~2h)

The two service repos were copy-pasted from each other and have drifted. Shared
infrastructure values (VPC, subnets, ALB, cluster) are hardcoded everywhere.

1. Extract the common "Fargate service behind the shared ALB" pattern into a
   **reusable Terraform module**. You decide the interface and where it lives.
2. Replace the hardcoded network/cluster values with values **consumed from
   `core-infra`'s state** (it uses a local backend — `../core-infra/terraform.tfstate`).
3. Both service repos must use the module and produce a clean `terraform plan`.

Don't aim for a do-everything module. Aim for the interface you'd be happy to
maintain across many service repos.

## Part 2 — Incident (~1h)

Read `INCIDENT.md`. The on-call engineer believes the problems are in
`svc-notifications`'s infrastructure code (the application image itself is fine,
and `svc-appointments` runs the same pattern without issues).

1. Identify the root cause(s) — there is more than one.
2. Fix them (in your refactored code is fine).
3. Write `RCA.md` (max 1 page): **Symptoms → Root cause(s) → Fix → Prevention**.
   For prevention, name the guardrail that would have caught each class of issue before production.

## Part 3 — Written answers (~30 min)

In `NOTES.md`, answer briefly (bullets welcome):

1. How would you **version and distribute** your module across many service repos
   (git tags? registry? monorepo?), and why?
2. You need to ship a **breaking change** to the module. How do you roll it out
   across all repos without freezing every team?

## Stretch (optional, only if inside the time box)

Add a CI check (GitHub Actions or pre-commit) you'd run on every service repo:
fmt / validate / tflint / policy — your pick. A stub + README note is enough.

## Deliverables

- Refactored Terraform (module + both service repos), `terraform plan` clean
- `RCA.md`
- `NOTES.md` (Part 3 answers + anything you cut for time)
- Git history with clear commit messages

## What we evaluate

Module interface design · correct cross-repo dependency wiring · root-cause accuracy
and depth of the RCA · production judgement (what you flag beyond the asked tasks) ·
clarity of written communication · sensible use of the time box.
