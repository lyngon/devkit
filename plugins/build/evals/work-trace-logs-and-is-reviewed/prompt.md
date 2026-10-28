---
plugins: ["../../.."]
max_turns: 80
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit, Bash]
---
/build:work-trace Add an option `--json` to the command `rates rate` in rates/cli.py, which prints the rate as a JSON object with the keys `base`, `quote` and `rate` instead of the bare number, and commit it. The working directory is the repository, a git repository on its default branch with one commit. Nobody answers questions in this session.
