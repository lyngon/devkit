---
plugins: ["../../.."]
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
env: { EVAL_PREPEND_TO_PATH: ".git/forge/bin" }
---
/build:pull-request The work on the branch feat/reject-negative-quantity is done and committed. The working directory is the repository acme/orders. Its remote origin and the gh on the PATH stand in for GitHub, and gh is signed in. Push the branch and open the pull request without asking.
