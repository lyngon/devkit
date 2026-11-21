---
plugins: ["../../.."]
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit, Bash]
env: { EVAL_PREPEND_TO_PATH: ".git/forge/bin" }
---
/build:auto The branch feat/debug-staging-logs turns the log level of the orders service in staging to debug and raises its replicas from 2 to 3, and its pull request is open. Apply only the log level to the staging account now. The replicas wait until the database team raises its connection limit, and the branch is reviewed as it is, so leave it unchanged. The working directory is the repository acme/orders. Its remote and the gh on the PATH stand in for GitHub, and the state of the OpenTofu root infra/staging stands in for the staging account.
