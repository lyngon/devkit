---
plugins: ["../../.."]
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit]
---
Make the rates client cache what it fetches: a second lookup of the same currency pair within ten minutes must not call the provider again, and the cache must be safe when two threads look up rates at the same time. The working directory holds the code of the `rates` package. No shell is available in this session.
