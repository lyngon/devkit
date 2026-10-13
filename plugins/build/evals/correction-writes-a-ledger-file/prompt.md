---
plugins: ["../../.."]
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write]
---
/build:correction You worked out the VAT in src/billing/vat.py with a float. Money is an integer of the minor unit in this repository, and I have fixed the code myself. The working directory is the repository. No shell is available in this session, and the pull request of this change is not open yet.
