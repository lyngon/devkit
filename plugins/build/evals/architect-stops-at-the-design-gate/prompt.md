---
plugins: ["../../.."]
max_turns: 120
timeout_seconds: 2700
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit, Bash]
---
/build:architect Add a second exchange-rate provider beside the one in rates/client.py, so that a lookup falls back to it when the first provider fails, and so that a third provider later takes one new file and no change elsewhere. Show me the design before you implement anything. The working directory is the repository, a git repository on its default branch with one commit.
