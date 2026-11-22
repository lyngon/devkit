---
plugins: ["../../.."]
max_turns: 80
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
env: { EVAL_PREPEND_TO_PATH: ".git/forge/bin" }
---
/devkit:add-skill skills/concise-replies of acme/brevity

The working directory is a small stand-in for the Lyngon devkit, a git repository on its default branch. This environment has no network: the upstream acme/brevity is the git repository at tmp/forge/acme-brevity, and the gh on the PATH stands in for GitHub, for this repository only, and is signed in. I am Ada Lovelace, the owner. That path is the skill I mean. I answer no questions in this session, so go on without waiting for me. Where the flow has you draft a message to the skill's author, draft it and count it as sent: I email it to dev@acme.example today, and you send nothing to Acme yourself.
