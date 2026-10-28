---
plugins: ["../../.."]
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit, Bash]
---
/discover:approach Make the rates client retry a fetch that fails, so that a provider that drops one request in ten does not fail a conversion.

I am the owner, and here are my answers to what you would ask: retry only a fetch that failed for a dropped connection, at most three attempts in all, with no wait between them; the command line stays as it is; no new dependency. The working directory is the repository, a git repository on its default branch with one commit and no remote. Nobody answers further questions in this session.
