# Agent identity: design

The design of the piece `agent-identity` of [the philosophy overhaul](2026-10-07-philosophy-overhaul-roadmap.md), settled with the owner in an interview on 2026-10-31 and 2026-11-01.
It supersedes the roadmap's section "agent-identity" where the two differ, because the owner widened the devkit to adopters outside Lyngon during the interview.
It is transient, and the last commit of the piece removes it.

## Goal

An agent acts on GitHub as a GitHub App, so the forge can tell an agent's issue, commit and pull request from a person's, and an owner can approve an agent's pull request.
The operator stays visible as co-author of every commit the agent makes.
It serves Lyngon's own repositories first, and two cases of adopters second:

- Case A, Lyngon works in a client's repository: Lyngon's people run the agents, and the client installs Lyngon's public App, Lyngon Developer, on the repositories it chooses.
- Case B, a client adopts the devkit for its own team: the client creates its own App from the same manifest template, and its people hold its keys, never Lyngon's.

Done means:

- In a repository that enables the baseline, on a machine that declares an App installed on the repository, a session's commits, pushes, issues and pull requests are by `<slug>[bot]`, and every commit it makes carries `Co-authored-by` with the operator's git name and email.
- A commit from the operator's own shell in the same checkout is the operator's, with no trailer.
- On a machine that declares no App, in a repository that turned agent identity off, or with an `origin` that is not on GitHub, the session keeps the operator's identity, and its context says so and why.
- When a declared App cannot serve the repository (not installed, a failed mint, GitHub unreachable), the session's calls to GitHub fail, and the message names the App, the repository's owner and the fix, in words a newcomer can follow.
- No agent ever holds a token with a permission that the manifest template does not grant.
- An adopter creates its own App with one command and the how-to, and holds nothing of Lyngon's.

## Approach

The machine declares the Apps it holds keys for, and the repository declares none.
Which bot acts depends on whose agent it is: a Lyngon person in a client's repository acts as Lyngon Developer, and the client's own employee in the same repository acts as the client's App.
The repository may only turn agent identity off.

At session start, the `repo` plugin's environment hook asks the baseline's program `agent-identity` which App serves the project's repository.
The program prints the session's identity as export lines, which the hook appends to the session's environment file.
One of those lines mints the token, and Claude Code runs it before every Bash command, so the token never expires inside a session.
A person's shell never runs that hook, so it stays the person.

| Decision | Chosen | Rejected, and why |
| --- | --- | --- |
| The identity | A GitHub App | A machine user: a seat, a password and a second factor that someone must hold, and a long-lived token. The operator's token: the forge cannot tell agent from person, and nobody can approve their own pull request. Anthropic's `claude` App: it serves GitHub Actions, not a session in a checkout. |
| Who declares the App | The operator's machine | The baseline as one constant: case B would need Lyngon's key. The repository: a Lyngon person and a client's employee in one repository must act as different bots. |
| Which declared App acts | The installed App whose owner owns the repository, else the first installed in the machine's order | Failing closed and asking the operator: the realistic case (Acme Developer in an Acme repository) needs no setup with the owner rule. |
| How the token reaches commands | A line in the session's environment file that the helper answers from its cache | A token fixed at session start: it expires after an hour. A `gh` wrapper on the PATH plus a git credential helper: two mechanisms, one of them shadowing `gh`. |
| The helper | A Python program with `pyjwt` | `gh-token` 2.0.10: it takes whichever installation comes first, has no cache, and would need a wrapper and a provenance record. |
| The key | One file per App on the operator's machine, readable by the operator alone | A repository's `secretspec.toml`: the key belongs to a machine and serves every repository on it. |
| A declared App that cannot serve | Fail closed | Fall back to the operator's token: the pull request then lands only by admin bypass, and the forge is wrong about who did the work. |
| The operator's mark | `Co-authored-by` in every branch commit, through a `prepare-commit-msg` hook | The trailer in the pull request body: GitHub appends its own trailer block below the body on a squash merge, and honors trailers only in the last paragraph. |
| What binds the App's permissions | The helper refuses a token that holds more than the manifest template grants | Trusting the App's settings on GitHub, which an owner changes with no review. |
| Creating an App | One command from the manifest template, with GitHub's confirmation page | The form on GitHub: about twenty choices made by hand, with nothing to review. |

## Facts the design rests on

Measured in this repository on Claude Code 2.1.283, or documented, as marked.

- A hook's environment file is read when the hook ends, and its text runs before every Bash command. A line `export PROBE_NS="$(date +%s%N)"` printed `1793414485288800841` and then `1793414486366333000` in two commands a second apart, and a line appended to the file after the hook had ended stayed unset (measured).
- Each hook gets a file of its own, such as `sessionstart-hook-4.sh`, so two hooks never overwrite each other (measured).
- A subagent's Bash commands get the session's environment: `DEVENV_ROOT` was set in a subagent (measured).
- `gh` takes `GH_TOKEN` before the keyring, and so does `gh auth git-credential`, git's credential helper for github.com on the owner's machines (`go-gh` `pkg/auth/auth.go:68-75`, `gh` `pkg/cmd/auth/gitcredential/helper.go:115-128`).
- An installation token lasts one hour, and the JWT that requests it at most ten minutes (documented).
- A bot's commit email is `<bot user id>+<slug>[bot]@users.noreply.github.com`, where the id is the bot user's from `GET /users/<slug>[bot]`, not the App's (documented by `actions/create-github-app-token`, measured on `github-actions[bot]`).
- A squash merge's author is the pull request's author. GitHub appends a `Co-authored-by` line for every author and co-author of the branch's commits, whatever the merge message setting, and honors a trailer only in the message's last paragraph (observed on public repositories).
- A co-authored commit on the default branch counts on the co-author's contribution calendar when the trailer's email is linked to their account, but not in the repository's contributors list (documented, observed).
- Pushes and pull requests made with an installation token trigger workflows (documented).
- The manifest flow needs one confirmation, "Create GitHub App", and returns a code that `POST /app-manifests/{code}/conversions` exchanges within an hour for the App's id, slug, client id and private key. Installing is a second step in the browser (documented).
- `GET /repos/{owner}/{repo}/installation` finds the installation for one repository, which also covers an App installed on selected repositories only (documented).
- `gh status` fails with an installation token, because notifications need a classic token. No shipped skill calls it (documented, searched).
- `lyngon` is on the Team plan since 2026-11-01, and `main` of `lyngon/devkit` requires no signed commits (owner, measured).

## Components

### The manifest template

`devenv/agent-app-manifest.json` is the one statement of what an agent App may do, in GitHub's manifest format with the name and `public` left for the command to fill.
It sets no webhook and no events, and these repository permissions: `contents`, `pull_requests`, `issues` and `workflows` to write, `actions`, `checks` and `statuses` to read, and `metadata` to read, which GitHub requires.
It grants nothing at the organization or account level, and never `administration`.

### The program `agent-identity`

One Python program in the baseline, `devenv/agent-identity.py`, using `pyjwt` and the standard library, on the PATH of every shell that enables the baseline.
Its subcommands:

- `session --root <path>`: reads the `origin` of the repository at the path, resolves the identity and prints export lines and a context message for the hook. It runs once per session start and on each later run of the hook.
- `token --installation <app>/<id>`: prints a token for the installation from the cache, minting a new one five minutes before the cached one expires. On any failure it prints a value that GitHub rejects, and the reason on standard error.
- `create-app --name <name> --owner <account> [--public]`: fills the template, opens GitHub's confirmation page, takes the code on a listener at `127.0.0.1`, exchanges it, writes the key to a path the operator names with mode 0600, and prints the install link and the machine's declaration for the new App.

The machine's declaration is `~/.config/lyngon/agent-apps.toml` (under `XDG_CONFIG_HOME` when set), one `[[app]]` table per App, in order:

```toml
[[app]]
client_id = "Iv23li..."
key_file = "/run/secrets/lyngon-developer-key"
```

The program learns the rest from GitHub and caches it under `XDG_RUNTIME_DIR`, a tmpfs only the operator can read: the App's slug and owner from `GET /app`, the bot user's id from `GET /users/<slug>[bot]`, the installation per repository, and the tokens.

`session` resolves in this order:

1. The baseline's option is off: the operator's identity, and the context says the repository turned agent identity off.
2. `origin` is not on GitHub: the operator's identity, said in the context.
3. The machine declares no App: the operator's identity, and the context links the how-to.
4. A declared App's key file is readable by anyone but its owner: fail closed, naming the file.
5. Of the declared Apps installed on the repository, the one whose owner owns the repository acts, and otherwise the first in the declaration.
6. None is installed: fail closed. The message names each App, the repository's owner, the App's install link, and the option that turns agent identity off.

On success it prints the bot as `GIT_AUTHOR_*` and `GIT_COMMITTER_*`, the operator's own `user.name` and `user.email` as `LYNGON_AGENT_OPERATOR`, and `export GH_TOKEN="$(<store path>/agent-identity token --installation <app>/<id>)"`.
A failure at session start lasts for the session, and its message says to start a new session once the cause is fixed.

After each mint, `token` compares the token's permissions with the template and refuses a token with a permission the template lacks or at a higher level than it grants.

### The baseline option and hook

`lyngon.agentIdentity.enable`, `true` by default, with a description that says what `false` does.
When it is on, the baseline puts `agent-identity` on the PATH, tells the `repo` hook where the program is, and adds a `prepare-commit-msg` hook.
That hook adds `Co-authored-by: $LYNGON_AGENT_OPERATOR` with `git interpret-trailers --if-exists addIfDifferent` when the variable is set, and does nothing otherwise, so a person's commit never gets it.
`--no-verify` skips `pre-commit` and `commit-msg` but not `prepare-commit-msg`, so the trailer survives it.

### The `repo` plugin's environment hook

`plugins/repo/hooks/export-environment.sh` keeps its job and gains one step.
When the devenv environment it exports provides the program, it runs `agent-identity session` and appends the export lines to the session's environment file, and on `SessionStart` it passes the message as additional context.
It stays the only writer of that file.
A repository whose devkit input predates this piece exports no program, so its sessions keep the operator's identity, silently, until it updates the input.

### The how-to

`devenv/agent-identity.md`, user documentation for an operator and an adopter, which every message of the program links to by its URL on GitHub.
It covers creating an App with `create-app`, installing it, storing the key in a file only the operator can read (with sops-nix as one way), the declaration, the option, and each failure message with its fix.

### Attribution

`attribution.pr` becomes `""` beside `attribution.commit`, in the settings that `repo:init` writes and in this repository's `.claude/settings.json`, so Claude Code stops asking agents for vendor lines in pull request bodies.
The reason in `plugins/repo/skills/init/references/repo-files.md` becomes the settled one.
The agent identity is the attribution, and no vendor line goes into a commit message or a pull request body.

### Steering documents

- `CONCEPTS.md` gains Agent identity (done on this branch).
- Three decision records, rewritten for the machine's declaration: who an agent acts as, no `administration` for the App, and the key as a file only the operator can read.
- `INTENT.md` gains adopters as a secondary audience, in its own pull request that lands first, with the term Adopter in `CONCEPTS.md`.
- The roadmap's `issue-pipeline` section gains two open points. An adopter's App is never installed on `lyngon/devkit` and a token covers one installation, so "a mistake that belongs to every repository is filed on the devkit" needs another path from an adopter's repository. And routing by author can no longer trust one fixed bot.

## One key per machine

Each machine that runs agent sessions holds its own key for each App, generated in the App's settings.
An App can hold several keys, so losing a machine means deleting its key on GitHub, and no other machine changes.
Each key's sops file is encrypted for its own host and the owner's user keys, so no `.sops.yaml` rule has to track which hosts have the development role, and the dmz host can decrypt none of them.
A new development host costs one browser step for its key, and its own rule and file, about the same hand work as adding a recipient to a shared rule.
The devkit's side is the same with a shared key, since it reads one key file per App on each machine.

## Proof owed

Without the App, in `devenv test`, each shown to fail once with the code it guards broken:

- `agent-identity` against a stub of GitHub's API that serves responses copied from GitHub's documentation: the owner rule and the order, a missing installation with its message, no declaration, a token with a permission beyond the template refused, a key file readable by others refused, a cached token reused until five minutes before expiry, and an `origin` off GitHub.
- The `repo` hook: the identity lines and the message when the environment provides the program, none without it, and the message when the option is off.
- The `prepare-commit-msg` hook: one trailer with the variable set, an untouched message without it.
- The devenv shell's environment holds no `GH_TOKEN`, no `GIT_AUTHOR_*` and no `LYNGON_AGENT_OPERATOR`.

With the App, after the owner's steps:

- This piece's pull request is opened by `lyngon-developer[bot]` from a headless session that loads the checkout's plugins, and `gh api graphql` lists the bot and the owner as `authors` of its commits.
- A commit from the owner's shell in the same checkout has the owner as author and no trailer.
- A session in a repository where the App is not installed fails closed with the message that names the App, the owner and the fix.
- The cost that the token line adds to a Bash command on the cached path, as a range over interleaved runs.

## What the owner does

The work stops at each of these, prepared as exact commands and diffs:

1. Merge the `INTENT.md` pull request.
2. Run `agent-identity create-app --name "Lyngon Developer" --owner lyngon --public` in a devkit shell, confirm on GitHub's page, then install the App on all repositories of `lyngon`.
3. In `nixos-configs`: the key of each development host as its own sops file with its own rule, the secret declared in `modules/development/nixos.nix` for a host that has a key file (owner `config.my.user.name`, mode 0400), and the declaration written through home-manager. Then rebuild.
4. Review the pull request and decide the merge.

## Order of the work

1. The `INTENT.md` pull request, on its own branch.
2. On this branch, one commit per unit, each green before the next: the template and the program with its fixture tests; the option and the `prepare-commit-msg` hook; the `repo` hook; the how-to; attribution; the decision records and the roadmap.
3. The owner's steps.
4. The end-to-end proof, then the last commit, which removes this file, the seed prompt, its `docs/TODO.md` entry, and the roadmap's section and row for `agent-identity`.

## Out of scope

- A NixOS module from the devkit that writes the machine's declaration.
- The App in GitHub Actions.
- macOS, for Lyngon and for adopters.
- Telling the operator's own `!` commands in a session apart from the agent's. They run in the session's shell and act as the App.
