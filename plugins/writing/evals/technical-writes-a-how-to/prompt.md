---
max_turns: 20
allowed_tools: [Read, Glob, Grep, Skill]
---
Turn these notes into the how-to page for our docs site. Reply with the page as Markdown and nothing else, and write no file. The working directory is empty, and everything you need is in the notes.

Notes from Dana, who runs the service:

- keys are managed in the dashboard and/or the CLI (keyctl), this page is about the CLI
- in order to rotate you simply run keyctl rotate --grace 24h; the old key(s) keep working during the grace period, i.e. for 24 hours
- the new key should be copied from the output at this point, it is shown only once!!
- workers that cache the key (e.g. the billing worker) must be restarted after the rotation, restart = systemctl restart billing-worker
- please utilize keyctl list to verify, the old key should say "retiring" and the new one "active", etc.
- if the service is in read-only mode the rotation is going to fail, turn that off first with keyctl mode read-write
