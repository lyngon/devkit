# A go-ahead is an answer or a merge, never a permission prompt

In a session, the owner gives a go-ahead by answering, in the conversation, a message that named the proposals, as at every other gate.
In CI, merging the pull request that showed a proposal is the go-ahead for that proposal.
An `ask` permission rule on the command that runs a proposal was rejected: it hardens only the yes, while the weak point is whether the agent sees the target as protected and the mutation as irreversible, which no rule on a command can see.

## Considered options

- An `ask` rule prompts in auto mode, but the Claude Code documentation does not say what it does under bypassPermissions, and a headless run denies it, so no eval could show a run after a go-ahead.
- A permission prompt and an answer together make the owner say yes twice for one proposal.

Enforced by: judgment
