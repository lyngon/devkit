# Agents act on GitHub only as the organization's App

Agents pushed with the owner's token, so the forge could not tell an agent's issue, commit or pull request from the owner's, and the owner could not approve an agent's pull request, because nobody can approve their own.
Every agent session in a repository that enables the baseline therefore acts as the GitHub App Lyngon Agent (`lyngon-agent[bot]`), which the `lyngon` organization owns and has installed on all its repositories, while a person's own shell in the same checkout stays that person.
When a session cannot get the App's token, its calls to GitHub fail, and it never falls back to the operator's token.

## Considered options

- A machine user: rejected, because it takes a seat, needs a password and a second factor that someone must hold, and works through a long-lived token.
- The operator's own token, as before: rejected for the two reasons above.
- Anthropic's `claude` App: it serves agents that run in GitHub Actions and cannot serve a session in a checkout.
- A mark of the operator on the agent's work, such as a `Co-authored-by` trailer: left out while one person runs agents, because GitHub would then credit the operator too.

## Consequences

- The App is not a sandbox. The agent runs as the operator's Unix user and can read the App's key and the operator's own token, so the identity catches honest mistakes and gives provenance, nothing more.
- A bot cannot be an assignee, so an agent claims an issue through its linked branch.
- One bot serves every person's agents, so the forge shows that an agent did the work but not whose session it was.
- A command the operator runs inside the session with `!` runs in the session's shell, and so acts as the App.

Enforced by: test-repo-hooks and judgment
