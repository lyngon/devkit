---
plugins: ["../../.."]
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit, Bash]
---
Refactor rates/cli.py so that `main` only parses the arguments and hands each command to a function of its own, and commit it. The working directory is the repository, a git repository on its default branch with one commit and no remote. Nobody answers questions in this session.
