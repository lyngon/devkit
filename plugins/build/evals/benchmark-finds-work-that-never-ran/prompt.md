---
plugins: ["../../.."]
max_turns: 60
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Edit, Bash]
---
/build:benchmark NOTES.md claims that parse_lazy is many times faster than parse_eager, measured with bench.py. Vet the claim before it goes into the release notes. The working directory holds the code, bench.py and NOTES.md, and python3 is on the PATH. Nobody answers questions in this session.
