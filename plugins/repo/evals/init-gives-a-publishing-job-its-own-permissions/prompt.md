---
plugins: ["../../.."]
max_turns: 80
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Write]
---
/repo:init fresh

This directory is empty: no files, no commits and no remote. No shell is available in this session, so take that as the inventory, and leave out the verification and the commit.
I cannot answer a question in this session. Below is my answer to every question of the interview, and I confirm in advance the shared understanding and the file set that follow from these answers. Ask nothing and write the files.

- Failure in a year: the relay drops a webhook without a trace, or nobody trusts its delivery log.
- Problem: partner systems send webhooks to three internal services, and each service has its own retry code. The relay receives every webhook once and forwards it with retries.
- Non-goals: transforming a payload, and serving anything but webhooks.
- Lifetime: years.
- Repository audience: the Lyngon platform team.
- Artifact audience: the internal services that receive webhooks.
- Technologies: Go.
- Structure: no. The repository keeps the standard Go layout, with `cmd/relay` and `internal/`.
- Delivery: one container image, `ghcr.io/lyngon/webhook-relay`, pushed on every push to `main`. The application code and its `Dockerfile` come in a later change, so write neither.
- Git host and CI: GitHub with GitHub Actions.
- Constraints, secrets and services: none.
- Test strategy: unit tests with `go test ./...`, which `devenv test` runs.
- Terms, stack choices with lock-in, decision records and rule files: none. Leave the commented linters commented.
