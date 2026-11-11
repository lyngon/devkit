# The tool

`scripts/live-mutation.py` of this skill keeps one directory per proposal, `tmp/live-mutation/<session>/<name>/` at the root of the repository, where `<session>` is the session that proposed it.
Run it from the root of the repository, in the conversation that asks the owner.
It refuses to work outside a Claude Code session.

Each command is one line of sh, run from the root of the repository.
`$LIVE_MUTATION_INPUTS` names the directory of the frozen inputs: the derive command writes them there, and the show and run commands read them from there.
Quote the command lines in single quotes, so that the tool's shell expands the variable and yours does not.

## propose

```sh
live-mutation.py propose <name> --derive '<cmd>' --show '<cmd>' --run '<cmd>' --check '<check>=<cmd>'...
```

It derives the inputs, renders them, runs each check once and prints the proposal: the digest, the command that runs, the rendering and each check's result.
It ends with the command that runs the proposal on a go-ahead, which names the tool by its absolute path, so a later turn needs no search for it.
A name is kebab-case and says what the live mutation does.
Proposing a name again replaces a proposal that has not run, and its digest changes.
A check that passes before the run shows nothing yet: give it a demonstration.

## demonstrate

```sh
live-mutation.py demonstrate <name> <check> '<cmd>'
```

It runs a variant of a check's command against a state where the property does not hold, and logs it, so that the record shows the check can fail.

## run

```sh
live-mutation.py run <name> <digest> --go-ahead '<the owner's words>'
```

It derives and renders again from live state, runs the command once when the rendering is still the one the owner read, then runs every check again.
The go-ahead is quoted word for word.
Each refusal changes nothing live:

- `not-in-this-conversation`: another session showed the proposal. Propose it again here and ask again.
- `digest-mismatch`: the digest is not the one the proposal has now, as after a second propose. Show the owner the proposal at its digest and ask again.
- `inputs-changed`: a frozen input changed after the proposal. Propose again.
- `drifted`: live state no longer gives the rendering the owner read, and the refusal prints the difference. Propose again and ask again.
- `already-ran`: a go-ahead covers one run. Propose again from the new live state.

A run can take longer than a command in the foreground may, as a landing zone upgrade does.
Start such a run in the background and wait for it to end.
Its output grows in the file that the tool names, under `outputs/`.

## record

```sh
live-mutation.py record <name>
```

It writes the action record as one or more Markdown files, `record-1.md` and on, each within the size of a GitHub comment, and prints their paths.
Post each one, in order, with `gh pr comment <number> --body-file <file>` or `gh issue comment <number> --body-file <file>`.
It refuses `check-never-failed` when a check has no failing run.

When a session ended before it posted the record of its run, the proposal stays in its session's directory.
The next session writes that record with `--session <the session>`, posts it, and proposes again from live state.

## With OpenTofu

```sh
live-mutation.py propose import-organization \
  --derive 'tofu -chdir=organization plan -input=false -out="$LIVE_MUTATION_INPUTS/plan"' \
  --show 'tofu -chdir=organization show -no-color "$LIVE_MUTATION_INPUTS/plan"' \
  --run 'tofu -chdir=organization apply -input=false "$LIVE_MUTATION_INPUTS/plan"' \
  --check 'no-changes=tofu -chdir=organization plan -input=false -detailed-exitcode'
```

`$LIVE_MUTATION_INPUTS` is an absolute path, so `-chdir` leaves the plan file where the tool looks for it.
Two plans of one state differ byte for byte while `tofu show -no-color` renders them alike, which is why the tool compares renderings.
`no-changes` exits 2 before the apply and 0 after it, so its run before the apply is its failing run.

A destroy is planned with `plan -destroy -out`, and an import is an `import` block in the code, planned like any change.
A command that has no inputs, such as `tofu force-unlock`, derives nothing (`--derive true`) and shows what it acts on.
