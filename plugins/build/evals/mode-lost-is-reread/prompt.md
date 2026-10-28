---
plugins: ["../../.."]
max_turns: 100
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit, Bash]
---
Now give the command `rates convert` the same option --json, printing a JSON object with the keys amount, base, quote and converted.
