---
plugins: ["../../.."]
max_turns: 120
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit, Bash]
---
/build:auto Clean the comments of the branch feat/rate-cache with build:clean-comments, and commit what changes. The working directory is a git repository on that branch, whose one commit against main adds a cache of exchange rates. Its full check is `python3 -m compileall -q rates`. It has no remote, so the task ends with the commits, and no pull request. Nobody answers questions in this session.
