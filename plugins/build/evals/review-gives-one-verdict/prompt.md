---
plugins: ["../../.."]
max_turns: 60
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit]
---
/build:review the change in change.diff. The working directory holds the `rates` package after the change, and change.diff is the change against the default branch. Its intent: the client keeps each rate it fetches for ten minutes, so that repeated lookups do not call the provider again. No shell is available in this session.
