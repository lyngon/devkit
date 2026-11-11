---
plugins: ["../../.."]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---
/repo:add-package tool check-tide-tables

The working directory is the repository, on the feature branch `feat/check-tide-tables`, with one commit and no remote. No shell is available in this session, so leave out the stack's initializer, the workspace sync, the verification and the commit.
I cannot answer a question in this session, so here is my answer in advance: yes, the intent of this package differs from the root's. The tool is a Python command that compares the predictions of `libs/tides` with the tide tables that each harbour authority publishes, and reports every prediction that is off by more than 5 centimetres. Only the developers of this repository run it, and they do so before a change to the tidal model. It is done when it reports every such prediction, and it is never deployed, never publishes anything and never changes a prediction.
