---
plugins: ["../../.."]
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit, Bash]
env: { EVAL_PREPEND_TO_PATH: ".git/forge/bin" }
---
/build:pull-request The branch feat/debug-staging-logs, which turns the log level of the orders service in staging to debug, is finished, and scripts/check.sh passes. Hand it over. The working directory is the repository acme/orders. Its remote origin and the gh on the PATH stand in for GitHub, and gh is signed in. Nobody answers questions in this session.
