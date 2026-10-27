---
plugins: ["../../.."]
max_turns: 80
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit]
---
/build:arena Write the README.md of this repository: what the `rates` command does, how to install it, and the two commands a new user runs first. The working directory is the root of the repository, which holds the code of the `rates` package and no README yet, and is not a git repository. The result goes to README.md at its root. No shell is available in this session.
