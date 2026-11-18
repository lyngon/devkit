# The tool

`scripts/live-mutation.py` of this skill keeps one directory per proposal, `tmp/live-mutation/<session>/<name>/` at the root of the repository, where `<session>` is the session that proposed it.
Run it from the root of the repository, in the conversation that shows the proposal.
It refuses to work outside a Claude Code session.
It guards against a wrong judgment and an accident, and not against an agent that sets out to rewrite its files, its environment or its PATH.

Each command is one line of sh, run from the root of the repository.
`$LIVE_MUTATION_INPUTS` names the directory of the frozen inputs: the derive command writes them there, and the show and run commands read them from there.
Quote the command lines in single quotes, so that the tool's shell expands the variable and yours does not.

Three refusals are common to the commands:

- `no-conversation`: `CLAUDE_CODE_SESSION_ID` holds no session ID. Every command but `pending` refuses it, unless `--session` names the session.
- `bad-name`: a name is no kebab-case name, such as `org-import`.
- `corrupt`: a file of the proposal does not parse, or the proposal's digest is not the one that its commands, its inputs and its rendering give. `pending` lists such a proposal instead.

A proposal that the tool wrote before it had the OpenTofu form reads as one of the generic form, with no branch.

A command that runs git refuses `git-missing` when git is not on the PATH, and `git-failed`, with what git said, when a git command fails.

## propose

```sh
live-mutation.py propose <name> --derive '<cmd>' --show '<cmd>' --run '<cmd>' --check '<check>=<cmd>'...
```

It derives the inputs, renders them, runs each check once and prints the proposal: the digest, the command that runs, the rendering and each check's result.
It takes the digests of the inputs before the checks run, since a check reads live state and never writes the inputs.
It ends with the command that runs the proposal on a go-ahead, which names the tool by its absolute path, so a later turn needs no search for it.
A name is kebab-case and says what the live mutation does.
Proposing a name again replaces a proposal that has not run, and its digest changes.
A check that passes before the run shows nothing yet: give it a demonstration.
The proposal keeps the branch that HEAD is on, for `pending`.
A proposal of this generic form always waits for a go-ahead.

Its refusals:

- `already-ran`: a proposal of that name ran. Propose under a new name.
- `derive-failed` or `show-failed`: the derive or the show command exited with a status other than 0. The refusal names the file that holds its output.
- `inputs-changed`: a check changed an input while it ran. Fix the check and propose again.

## The OpenTofu form

```sh
live-mutation.py propose <name> --opentofu <root module> [--destroy] [--check '<check>=<cmd>']...
```

The root module is a directory relative to the root of the repository.
The tool writes the derive, show and run commands itself, and adds the check `no-changes` before the checks you give.
For `--opentofu environments/sandbox`, they are:

```sh
tofu -chdir=environments/sandbox plan -no-color -input=false -out="$LIVE_MUTATION_INPUTS/plan"
tofu -chdir=environments/sandbox show -no-color "$LIVE_MUTATION_INPUTS/plan"
tofu -chdir=environments/sandbox apply -no-color -input=false "$LIVE_MUTATION_INPUTS/plan"
tofu -chdir=environments/sandbox plan -no-color -input=false -detailed-exitcode
```

With `--destroy`, both plan commands take `-destroy` after `-input=false`.
They run the `tofu` on the PATH that the tool has.
`$LIVE_MUTATION_INPUTS` is an absolute path, so `-chdir` leaves the plan file where the tool looks for it.
Two plans of one state differ byte for byte while `tofu show -no-color` renders them alike, which is why the tool compares renderings.
`no-changes` exits 2 before the apply and 0 after it, so its run before the apply is its failing run.

The tool reads the plan's JSON from `tofu show -json` into memory and never writes it to a file, since it holds sensitive values in plain text.
The proposal ends with its route.
It needs no go-ahead only when none of these holds, and otherwise it waits and the output gives each that holds:

- A resource change of the plan has no action, an action beyond no-op, create, read and update, such as a delete, a replace or a forget, or a form that the tool cannot read.
- The configuration of the plan, in the root module or in any module that it calls, holds a provisioner, which runs code that the plan does not show.
- `TF_CLI_ARGS` or a `TF_CLI_ARGS_` variable is set in the tool's environment, since the form takes no plan argument beyond its own.
- `TF_DATA_DIR` is set in the tool's environment, since it picks a backend and a state that `-chdir` does not.
- `tofu -chdir=<root module> workspace show`, run in the tool's environment, fails or names a workspace other than `default`, as `TF_WORKSPACE` or a selected workspace does.
- HEAD is detached, so the action record has no branch to wait on.
- HEAD is on the default branch of origin, or on a branch whose upstream is that branch, so a push may land its commits where no pull request takes the action record.
- The tool cannot read the default branch of origin, a rule file there names `unprotected-roots` in a form that the tool does not read, or no rule file there lists the root module or a directory above it, as [The declaration](#the-declaration) says.

When it needs no go-ahead, the output names the rule file and gives the command that runs without one, to run only when you judge that the apply can be undone and that the plan reaches only the target that the rule names.
The command that runs on a go-ahead follows it.
When it waits, the output gives the command that runs on a go-ahead.

The tool reads none of the other variables that choose a backend, a provider or the configuration of the CLI, such as `TF_HTTP_ADDRESS`, `TF_FORCE_LOCAL_BACKEND`, `TF_CLI_CONFIG_FILE`, `TF_REATTACH_PROVIDERS` and the `TF_VAR_` variables, so whether one of them points the apply elsewhere is yours to judge.

A destroy is planned with `--destroy`, and it always waits, since its plan deletes every resource.
An import is an `import` block in the code, planned like any change.
A plan that needs any other argument, such as `-target`, `-replace` or `-var-file`, goes through the generic form.
So do `tofu import`, the `state` commands and `tofu force-unlock`, and all of them always wait.
A command that has no inputs, such as `tofu force-unlock`, derives nothing (`--derive true`) and shows what it acts on.

Beyond those of the generic form, its refusals:

- `bad-root`: the root module is absolute, holds `..`, passes through a symlink or names no directory. Name the directory itself, relative to the root of the repository.
- `reserved-check`: a check you give is named `no-changes`, which the form adds itself. Name it otherwise.
- `plan-unreadable`: `tofu show -json` failed, or printed no JSON with a list of resource changes and a configuration of modules that the tool reads.
- `nothing-to-apply`: the plan changes nothing, since `no-changes` passes, so the check could never fail.

### The declaration

A rule file declares root modules unprotected with a list of directories under `unprotected-roots:` in its frontmatter:

```markdown
---
unprotected-roots:
  - environments/sandbox
---
```

- The tool reads the `.md` files directly under `.claude/rules/` at the default branch of origin, with git. It asks origin which branch and commit that is, with `git ls-remote --symref origin HEAD`, and reads the files at `refs/remotes/origin/HEAD` only when that ref names the same branch at the same commit. A rule file that only your branch or the working tree holds counts for nothing.
- When origin cannot be reached, when its HEAD names no branch, or when `refs/remotes/origin/HEAD` is missing or names another branch or commit, no root module counts as unprotected, and the reason says what differed. Fetch origin, run `git remote set-head origin --auto` and propose again.
- A directory covers every root module at it or below it, matched on whole path components, so `environments/staging` covers `environments/staging/eu` and not `environments/staging-old`.
- The key stands once, on a line `unprotected-roots:` alone, and a block list follows it with one item per directory. An item is a plain relative directory of letters, digits, `_`, `.`, `-` and `/`, with no `..` and no glob. No comment stands between the key and the next key, at any indent.
- A rule file that names `unprotected-roots` in any other form makes every proposal of the OpenTofu form wait, and the reason names the file. A rule file without the key counts for nothing.
- The reader is `scripts/unprotected_roots.py`, beside the tool, which imports it.

## demonstrate

```sh
live-mutation.py demonstrate <name> <check> '<cmd>'
```

It runs a variant of a check's command against a state where the property does not hold, and logs it, so that the record shows the check can fail.
It refuses `not-in-this-conversation` for a proposal of another session, and `no-such-check` for a check that the proposal does not have.

## run

```sh
live-mutation.py run <name> <digest> --go-ahead '<the owner's words>'
live-mutation.py run <name> <digest>
```

It derives and renders again from live state, runs the command once when the rendering is still the one the proposal showed, then runs every check again.
With `--go-ahead`, any proposal runs, and the go-ahead is quoted word for word.
Without it, only a proposal of the OpenTofu form runs, and only when its output said that it needs no go-ahead and the tool still finds so.
For that it reads the frozen plan's JSON, its environment and the rule files again.
A proposal that was shown waiting never runs without a go-ahead, whatever changed since.
The log then names the rule file and the commit it was read at, in place of the owner's words.

It checks these in order, and each refusal changes nothing live:

1. `no-conversation`, as for every command.
2. `empty-go-ahead`: `--go-ahead` holds no words. Quote the owner's go-ahead word for word.
3. `bad-name`, as for every command.
4. `not-in-this-conversation`: another session showed the proposal. Propose it again here and ask again.
5. `corrupt`, as for every command.
6. `digest-mismatch`: the digest is not the one the proposal has now, as after a second propose. Show the owner the proposal at its digest and ask again.
7. `already-ran`: a proposal runs once, with a go-ahead or without one. Propose again from the new live state.
8. `inputs-changed`: a frozen input changed after the proposal. Propose again.
9. `plan-unreadable`, `git-missing` or `git-failed`, without `--go-ahead` only, while it reads the plan and the rule files again.
10. `needs-go-ahead`, without `--go-ahead` only: the proposal runs only on the owner's go-ahead. The refusal gives each reason, and says so when the proposal was shown waiting. Show the owner the proposal and ask.
11. `drift-check-failed`: deriving or rendering again failed. The refusal names the directory that holds its output.
12. `drifted`: live state no longer gives the rendering the proposal showed, and the refusal prints the difference. Propose again and ask again.

A run can take longer than a command in the foreground may, as a landing zone upgrade does.
Start such a run in the background and wait for it to end.
Its output grows in the file that the tool names, under `outputs/`.

## record

```sh
live-mutation.py record <name> [--session <id>]
```

It writes the action record as one or more Markdown files, `record-1.md` and on, each within the size of a GitHub comment, and prints their paths.
The record of a run without a go-ahead says that no go-ahead was asked, and names the rule file and the commit it was read at.
Post each one, in order, with `gh pr comment <number> --body-file <file>` or `gh issue comment <number> --body-file <file>`, then run `posted`.

Its refusals:

- `bad-session`: `--session` names no session ID. Name the session that `pending` lists.
- `not-found`: the session holds no proposal of that name.
- `not-run`: the proposal has not run.
- `check-never-failed`: a check has no failing run. Give it a demonstration.

## posted

```sh
live-mutation.py posted <name> <url>... [--session <id>]
```

It logs the URLs of the comments that hold the action record, which `gh pr comment` and `gh issue comment` print, so that `pending` no longer lists the run.
It refuses `bad-session`, `not-found` and `not-run` as `record` does, and `bad-url` for an argument that is no `https://` URL.

## pending

```sh
live-mutation.py pending
```

It lists the runs whose action record has no URL yet, in the order they ran, from every session of this working tree.
A run counts for the branch that HEAD was on at its proposal, and the list holds the runs of the branch that HEAD is on now.
A proposal that the tool wrote before it kept the branch counts for no branch, so `pending` lists none of its runs.
Each comes with its `record` and `posted` commands, which name its session.
Once the pull request is open, `build:pull-request` posts every record that `pending` lists.
It exits 1 when it cannot read a proposal, and names the file, since that run may wait too.
It refuses `detached-head` when HEAD is on no branch.

When a session ended before it posted the record of its run, the proposal stays in its session's directory, and `pending` lists the run.
The next session writes that record with `--session <the session>`, posts it, runs `posted` with the same `--session`, and proposes again from live state.
