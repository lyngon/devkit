---
plugins: ["../../.."]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---
/repo:add-package adapter tides-noaa

The working directory is the repository, on the feature branch `feat/tides-noaa`, with one commit and no remote. No shell is available in this session, so leave out the stack's initializer, the workspace sync, the verification and the commit.
The adapter implements the port through which `libs/tides` reads the heights of the water measured at a harbour, against the public API of NOAA's tide stations.
I cannot answer a question in this session, so here is my answer in advance: no, the intent of this package does not differ from the root's.
