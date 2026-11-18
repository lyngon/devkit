---
plugins: ["../../.."]
max_turns: 80
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit, Bash]
---
/build:clean-comments The working directory is a git repository on the branch feat/rate-cache, whose one commit against main adds a cache of exchange rates. Its full check is `python3 -m compileall -q rates`. Commit what you change. Nobody answers questions in this session.
