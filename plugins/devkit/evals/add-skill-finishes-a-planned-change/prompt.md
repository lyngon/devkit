---
plugins: ["../../.."]
max_turns: 150
timeout_seconds: 2700
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
env: { EVAL_PREPEND_TO_PATH: ".git/forge/bin" }
---
/devkit:add-skill skills/concise-replies of acme/brevity, as change 001-brevity of docs/plans/2026-10-20-short-answers.md

The working directory is a small stand-in for the Lyngon devkit, a git repository on its default branch. This environment has no network: the upstream acme/brevity is the git repository at tmp/forge/acme-brevity, the remote origin and the gh on the PATH stand in for GitHub, and gh is signed in. I am Ada Lovelace, the owner. That path is the skill I mean, and I have read its full text at the commit you will find there. I answer no questions in this session, so go on without waiting for me.
