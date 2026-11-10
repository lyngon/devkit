# A package agent file loads the package intent

A package with its own `INTENT.md` holds a `.claude/CLAUDE.md` with the one line `@../INTENT.md`, and Claude Code loads both when an agent reads, writes or edits a file of the package, in the lead and in subagents, and never in a session that touches no file of it.
A hook in the `repo` plugin was rejected: it would close the two gaps below, but it needs per-session state of which agent already holds which intent, and its text arrives as hook context instead of project instructions, for loading that Claude Code already does.
A rule file under `.claude/rules/` scoped to the package with `paths:` and importing its intent was rejected, because Claude Code loads an imported file at launch, whatever the rule's `paths:` say.

## Consequences

- A compaction drops the package intent until the next read, write or edit of a file in the package, which brings it back word for word before any change to the package: Claude Code 2.1.283 refuses an edit until the file is read again, and 2.1.319 loads the intent on the edit.
- On Claude Code 2.1.283, writing a new file in a package that the session never read does not load the intent; 2.1.299 and later load it.
- Working on a package means the file tools. A package that an agent only changes through the shell, or only searches with Grep and Glob, does not load its intent.

Enforced by: validate-documents rule package-agent-file-imports-intent, and judgment
