# An agent acts on GitHub as an App its operator's machine holds

Agents pushed with the owner's token, so the forge could not tell an agent's work from the owner's, and the owner could not approve an agent's pull request, because nobody can approve their own.
An agent session in a repository that enables the baseline therefore acts as a GitHub App that the operator's machine declares and holds a key for, and a person's own shell in the same checkout stays that person.
Which bot acts depends on whose agent it is, so the machine declares its Apps and the repository declares none.
Of the declared Apps installed on the repository, the one whose owner owns the repository acts, and otherwise the first in the machine's order.
A repository may only turn agent identity off.
When the machine declares no App, the repository turned it off, or `origin` is not on GitHub, the session keeps the operator's identity and says so.
When a declared App cannot serve the repository, the session's calls to GitHub fail and never fall back to the operator's token.
Every commit the agent makes names the operator in a `Co-authored-by` trailer.

## Considered options

- A machine user: rejected, because it takes a seat, needs a password and a second factor that someone must hold, and works through a long-lived token.
- The operator's own token, as before: rejected for the two reasons above.
- Anthropic's `claude` App: it serves agents that run in GitHub Actions and cannot serve a session in a checkout.
- One App for everybody, its constants in the baseline: rejected, because a client that adopts the devkit would then need Lyngon's key.
- The repository declares its App: rejected, because a Lyngon person and a client's employee in the same repository must act as different bots.
- The operator's trailer in the pull request body: rejected, because on a squash merge GitHub appends its own trailer block below the body and honors trailers only in the last paragraph.

## Consequences

- The App is not a sandbox. The agent runs as the operator's Unix user and can read the App's key and the operator's own token, so the identity catches honest mistakes and gives provenance, nothing more.
- A bot cannot be an assignee, so an agent claims an issue through its linked branch.
- The trailer puts the commit on the operator's contribution calendar, but a repository's contributors list counts authors only and shows the bot.
- A command the operator runs inside the session with `!` runs in the session's shell, and so acts as the App.

Enforced by: test-repo-hooks, the fixture tests of agent-identity and judgment
