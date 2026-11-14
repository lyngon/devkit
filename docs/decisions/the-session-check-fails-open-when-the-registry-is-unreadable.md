# The session check fails open when the registry is unreadable

The repo plugin learns which sessions are live from Claude Code's registry of live sessions under `~/.claude/sessions/`, whose format Claude Code does not document.
When the check cannot find its own session there, it lets every call run, and session start says that nothing stops a second session in this tree.
Failing closed would stop all work in every Lyngon repository on the day a Claude Code update moves or reshapes the registry, while failing open costs only the protection that existed before the check.

Enforced by: judgment
