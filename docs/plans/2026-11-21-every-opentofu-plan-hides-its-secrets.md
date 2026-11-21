# Every OpenTofu plan hides its secrets

The design of the fix of issue 207, on the branch `fix/every-opentofu-plan-hides-its-secrets`.

## Goal

What must hold, from the issue: no sensitive value of an OpenTofu plan enters a file under `tmp/live-mutation/` other than the saved plans, nor a record the tool writes, whichever form runs the plan.

Today only the OpenTofu form reads the plan's JSON and hides what it marks sensitive.
`references/the-tool.md` sends every plan that needs another argument to the generic form, which hides nothing, so a `-target` plan of a root module that feeds a sensitive variable to `terraform_data` writes the value into six files of the proposal, its record included.

Done means:

- Every OpenTofu plan that the tool derives is one of the OpenTofu form, a `-target` plan included, and a proposal that takes `--target` waits for a go-ahead.
- The generic form refuses a saved plan among its frozen inputs, and every command that runs an OpenTofu command that prints values.
- The OpenTofu form refuses a check or a demonstration that runs such a command against anything but its own root module.
- Each command that names `tofu` and that the tool cannot read is refused.
- The hook denies exactly what it denies today.
- The skill, `references/the-tool.md`, the plugin's README and the two decision records say the same, and this file is gone in the last commit.

## Settled with the owner

- Plan route: the OpenTofu form takes plan arguments as flags of its own and writes every command itself, and a proposal with any of them waits. An argument that the form does not take is refused, and the agent stops and tells the owner.
- Check plans: in scope. The tool refuses a value-printing OpenTofu command (`plan`, `show`, `output`, `state show`, `console`, and the others that [The reader](#the-reader) lists) in any command of the generic form, and in a check or a demonstration of the OpenTofu form that reads another root module. It reads commands with the reader that the hook gained in pull request 225. A check of another root module stays a read in the shell, outside the proposal. Learning each check's own secrets is left for later, on top of this refusal.
- Plan arguments: `-target` only. Each other argument comes with its first case.
- Own root: a run reads the form's own root module when its `-chdir` names that directory (no `-chdir` reads the root of the repository), the command holds no `cd`, `pushd` or `popd`, sets no `TF_` variable for the run, passes no `-state`, `-var` or `-var-file`, and a `show` reads no file but the frozen plan.

These are recorded in [An OpenTofu apply skips the go-ahead only when the tool finds it may](../decisions/an-opentofu-apply-skips-the-go-ahead-only-when-the-tool-finds-it-may.md) and [A proposal reads OpenTofu values only of the root module that it plans](../decisions/a-proposal-reads-opentofu-values-only-of-the-root-module-that-it-plans.md).

## Alternatives compared

Plan route.
The generic form could name the root module of its plan, so that the tool reads that plan's JSON.
Every argument would work with no rule in the tool, but the agent would keep writing the plan commands and the `no-changes` check by hand, and the check that leaked in the issue was one of those.
Nothing would check that the named root module is the one planned.
Passing any argument through the OpenTofu form fails on `no-changes`: measured with OpenTofu 1.11.8, with a `-replace` as the only change, a plain plan exits 0 before the apply and after it, and a plan with `-replace` exits 2 before and after.
The chosen route keeps one way to propose a plan, in which the tool writes every command.

The guard of the generic form.
Detecting a saved plan among the frozen inputs alone misses a plan that a check prints.
Reading commands alone misses a plan derived by a command that does not name `tofu`, such as a script of the repository.
Both run, since each misses what the other catches.
A saved plan is a zip archive whose members include `tfplan`, measured with the same OpenTofu.

Where the reader lives.
The hook reads every OpenTofu run of a shell command, through wrappers, shells, `eval`, here-documents and `xargs`, with `hooks/shell_syntax.py`, which three hooks import.
A copy of that reading in the tool would drift from the hook's with nothing failing.
The tool calling the hook as a program gets only a verdict on writes, not the runs it needs to judge.
So the reading moves into a module beside `shell_syntax.py` that both import, and the hook keeps only its verdict.
The tool adds the hooks directory to its import path, as the hook adds the tool's scripts directory to read `parser()`.

## Components

### The reader

A module in `plugins/build/hooks/` that turns a shell command into the OpenTofu runs it holds: for each, the global options, the subcommand and the arguments after it, or why the reader cannot read it, as the hook reads it today.
It also says whether the command holds a `cd`, `pushd` or `popd` call, and whether it sets a `TF_` variable for a run.
It owns the tables of what an OpenTofu command does: the commands that write, which the hook has today, and the commands that print values, which are new:

```text
plan, apply, destroy, refresh, test, show, output, console, state show, state pull
```

`state list`, `import`, the other `state` commands, `force-unlock` and `workspace show` print no values.

### The hook

`tofu-writes-go-through-live-mutation.py` takes its runs from the reader and keeps its verdicts, its reasons and its reading of the tool's command line.
`tests/hooks.sh` passes with no expectation changed.
The hook imports `parser()` of the tool and reads the `derive`, `show`, `check` and `cmd` of its result, so those stay as they are, and the tool does no work at import time beyond its imports.

### The tool

- `propose --opentofu <root> --target <address>...` writes `-target=<address>`, quoted, into the derive command and the `no-changes` check, after `-destroy` where the form has it. The proposal's JSON keeps the targets under `form`, and a proposal without them reads as one with none. A route of a proposal with targets waits, and gives the targets as its reason. `--target` without `--opentofu` is an error of the command line.
- Before it runs anything, `propose` reads each command of the generic form and each check of the OpenTofu form, `demonstrate` reads its command, and `run` reads the commands of a proposal of the generic form, as one written before this change. A value-printing run in the generic form, or one that does not read the OpenTofu form's own root module, is refused, and the refusal names the run and what it read. A command that names `tofu` and that the reader cannot read is refused with the reader's reason.
- After the derive of the generic form, at `propose` and in the drift check of `run`, a saved plan among the inputs is refused before the tool writes anything that the derive printed.
- The refusal `sensitive-value-shown` no longer tells the agent never to take the generic form, since that form now refuses the plan itself.

### The skill and its documents

- `SKILL.md`: the OpenTofu form proposes every plan, `--target` included, and a plan that needs any other argument stops for the owner. A check of another root module is a read in the shell, outside the proposal.
- `references/the-tool.md`: `--target` in the OpenTofu form, the reading of commands and its refusals, the saved plan of the generic form, and the generic form's place, which is `tofu import`, the `state` commands, `force-unlock` and everything that is not OpenTofu.
- `plugins/build/README.md`: the script's form of a plan, and the reader that the hook and the script share.

### The eval case

A new case, `live-mutation-proposes-a-targeted-plan-in-the-opentofu-form`, seeds a root module with two pending changes and asks for the apply of one of them.
Its graders: a `propose` with `--opentofu` and `--target`, a reply that ends on one question, and live state unchanged.
At the base, the skill sends the agent to the generic form, so the first grader is expected to fail there.

### Room for issue 208

Issue 208 learns the values that the state after a run marks sensitive.
After this change every apply that the tool runs is one of the OpenTofu form, and every value-printing check reads that form's root module, so reading that root module's state after the run covers every apply and every check.
The secrets of a proposal stay one set, which `secrets_in` returns for a form, so that issue adds a source to it and changes no caller.
Its session starts from main after this change merges.

## Proof owed

Each item is a run a reviewer can repeat, or a file to read.

- `plugins/build/tests/live-mutation.sh`, with a regression test committed before the fix: the generic proposal of the issue, a `-target` plan of `terraform_data.logging` whose input holds a sensitive variable, is refused, and no file under `tmp/live-mutation/` holds the token. At the base commit the test fails, since six files hold it.
- The same script: the OpenTofu form with `--target terraform_data.logging` waits with the target as its reason, plans and checks with `-target`, runs on a go-ahead and leaves the other pending change unapplied, and no file of the proposal but its saved plans, its record included, holds the token.
- The same script: a derive of the generic form that saves a plan through a script that does not name `tofu` is refused, with no file that holds the token.
- The same script: one case for each rule of the own root module, refused, and a read of the own root module (`output -json`), a `state list` check and a `state rm` run of the generic form, let through.
- `plugins/build/tests/hooks.sh` passes with no expectation changed.
- `devenv test` passes on the pushed head.
- The scores of the new case and of the live-mutation cases at the base commit and at head, from `scripts/compare-evals.py`. The case `live-mutation-runs-after-the-go-ahead` misses `links-the-record` in one or two runs of three at main for a reason of its own (issue 176), so a drop there counts against this change only where a trace shows it does.
