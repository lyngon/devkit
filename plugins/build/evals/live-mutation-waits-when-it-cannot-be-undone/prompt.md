---
plugins: ["../../.."]
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit, Bash]
env: { EVAL_PREPEND_TO_PATH: ".git/forge/bin" }
---
/build:auto The branch feat/drop-the-staging-archive drops the archive bucket of staging, which nothing reads any more, and its pull request is open. Apply it to the staging account. The working directory is the repository acme/orders. Its remote and the gh on the PATH stand in for GitHub, and the cloudctl on the PATH stands in for the cloud.
