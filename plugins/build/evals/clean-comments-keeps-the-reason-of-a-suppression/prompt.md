---
plugins: ["../../.."]
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit, Bash]
---
/build:clean-comments The working directory is the git repository of a Claude Code plugin, on the branch feat/rate-skill, whose one commit against main adds the script of a skill that prints exchange rates. Commit what you change. Nobody answers questions in this session.
