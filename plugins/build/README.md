# build

How a change is built and handed over in a Lyngon repository: a prompt or an issue in, proof and a pull request out.

## Skills

- `/build:auto <task>`: the mode for one task, which only the operator starts. It routes the task to a playbook under `skills/auto/playbooks/` (feature, refactoring, bug fix, prototype, autonomous run) or to `figure-it-out`, delegates code to the agent `build:implementer` (`agents/implementer.md`) and holds every claim of the reply to its evidence.
- `/build:pull-request [change]`: hand a finished change over as one pull request, with the comments cleaned, the full check green on the pushed head, a title and a body that `check-pull-request` accepts, and the action records that waited for it and the branch's work trace posted on it. The agent invokes it whenever a change is done.
- `/build:tdd [bug]`: fix a bug test first when a cheap test path exists, with the failing test committed before the fix and kept, and no test rather than a bad one.
- `/build:correction [mistake]`: record a mistake in the mistake ledger, one file under `docs/mistakes/`, and fix a mistake that repeats at the highest level that works: architecture, then types, then a lint, then a test, and a rule file last. The agent invokes it when the operator corrects it, a review finding is accepted or a change is reverted.
- `/build:architect <task>`: design before code. Ground the design with `discover:how`, sketch at least two structurally distinct candidates through `arena`, write the chosen sketch and its rationale into the design file under `docs/plans/`, then build against it, or stop there when the owner asked for a gate on the design.
- `/build:arena <task>`: run two or more candidates at the same task in parallel, score them against a rubric beside a judge on another model, pick a base and graft the best of the others into it. The candidates and the synthesis note live in a worktree or under `tmp/arena/` and are never committed.
- `/build:review [change]`: an adversarial review of a change by reviewers on different models, each with the same prompt, rubric and code-quality lens, judged into one verdict (act on, consider, noted, dismissed). It changes nothing.
- `/build:figure-it-out <task>`: for work that no narrower skill fits, such as a large migration. Frame a falsifiable definition of done and a rigor level, write a phase list with the verification harness first into the design file under `docs/plans/`, then run each unit as an experiment that is kept or reverted, with the trail in `work-trace`.
- `/build:work-trace [task]`: keep a decision trail of long or unattended work, one row per decision with its evidence, in `tmp/work-trace/<branch>.tsv`, written by the script `skills/work-trace/scripts/trace.py`. It is checked against the session's transcript and scanned by a reviewer on another model, whose Attention section lies beside it. It is never committed, and `pull-request` posts both on the pull request.
- `/build:benchmark [claim]`: vet a performance number before it is reported or acted on, with seven questions answered from runs (the limiter, tuning, limits, errors, repeatability, relevance, and whether the work happened), and report the verdict with the run count, the range and the limiter.
- `/build:clean-comments [scope]`: before a change goes to a pull request, have the agent `build:comment-auditor` (`agents/comment-auditor.md`) delete the comments of the change that its exceptions do not protect and flag the code they covered for, then vet its work, fix the flags at their root and encode each constraint a comment claimed.
- `/build:live-mutation [mutation]`: before a change to a running system or the state a tool keeps of one, such as an OpenTofu apply, decide whether it waits for the owner's go-ahead. One that waits is proposed with the script `skills/live-mutation/scripts/live-mutation.py`, shown to the owner, run once on a go-ahead in the same conversation after a drift check, judged by checks of live state that each failed once, and recorded in a comment on the pull request or issue. An OpenTofu command that writes runs only through the script. The apply of a saved plan, proposed in the script's OpenTofu form, runs without a go-ahead only when a rule file at the default branch of origin, as origin names it, lists its root module under `unprotected-roots:`, the plan deletes, replaces and imports nothing and holds no provisioner, the root module's workspace is `default`, no `TF_CLI_ARGS` variable and no `TF_DATA_DIR` is set, and the agent judges that the apply can be undone and reaches only the target that the rule names. The script's reader of that declaration is `skills/live-mutation/scripts/unprotected_roots.py`. The record of such a run waits for the pull request when the branch has none, and `pull-request` posts it. The standing instructions send every live mutation here.

The agent never starts `auto`, which carries `disable-model-invocation: true`.
It starts `architect`, `arena`, `review` and `figure-it-out` only when the operator asks for one of them, or when `auto` routes there or `architect` runs `arena` and `review`.
Each of the four spawns several subagents, directly or through the others.
The agent starts every other skill on its own trigger.

The skills and the agents are vendored from [pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT), all but the script of `correction` and the skill `live-mutation`, and the hooks are written by Lyngon.
Upstream, `auto` is called `poteto-mode`, `pull-request` is its playbook `opening-a-pr`, `correction` is `correct`, `review` `interrogate`, `work-trace` `show-me-your-work`, `benchmark` `benchmark-checklist`, `clean-comments` `no-comments`, `implementer` poteto-agent and `comment-auditor` Comment Sicko.
The license is `LICENSE-pstack` in this plugin, and the provenance record is [pstack.md](../../catalog/vendored/pstack.md) under `catalog/vendored/`.

## Hooks

- `SessionStart`: prints `hooks/standing-instructions.txt`, the standing instructions, at the start of every session and again after each compaction, with the path of the mode's file filled in. `validate-marketplace` fails the text above 4,000 characters, since every session pays for it, and the mode's `SKILL.md` above 15,000 characters or without `disable-model-invocation: true`. `tests/hooks.sh` runs the hook with nothing but bash on the PATH.
- `PreToolUse` on `Bash` and `Monitor`: `hooks/tofu-writes-go-through-live-mutation.py` denies an OpenTofu command that writes, and its reason names `build:live-mutation` as the way to run it.
  The lead proposes the command with the skill's script, which runs the apply of a saved plan on an unprotected root module without a go-ahead when it finds that it may, and every other write on the owner's go-ahead, and a subagent reports the command to its lead.
  The commands that write are `apply`, `destroy`, `import`, `force-unlock`, `refresh`, `taint`, `untaint`, `test`, `state rm`, `state mv`, `state push`, `state replace-provider`, `workspace delete`, `workspace new`, `workspace select -or-create`, and `init` with `-migrate-state` or `-force-copy`.
  `tofu test` creates real infrastructure, as its help says, and `init -force-copy` migrates state as `-migrate-state` does (measured on OpenTofu 1.11.8).
  Every other command runs untouched, and so does a command that writes when a `-help` flag before any `--` makes it print help only.
  The hook reads a command with `shfmt`, as bash and then as zsh, and finds tofu wherever a word names it, by its name, its path or the flake output `#opentofu`, so it also denies a write after a global option such as `-chdir`, after a `cd`, behind a wrapper such as `devenv shell --`, `aws-vault exec --`, `nix run`, `timeout` or `xargs`, inside a substitution or a loop, and in what `bash -c`, `sh -c` or `eval` runs.
  A variable that the command assigns once, to a literal value, counts as that value.
  It denies rather than asks, since the skill decides whether a live mutation waits for the owner, and it denies in a subagent as in the lead (measured on Claude Code 2.1.283 and 2.1.322).
  In a subagent, whose hook input holds an `agent_id`, it also denies a call of the script's `propose`, `demonstrate` or `run`, and tells the subagent to report to its lead.
  It counts the script only where the command may run it as a program, never as an argument of another program.
  A simple command runs its first word, and when that word is a wrapper such as `env`, `timeout`, `nix shell --command` or `python3`, or a variable hides it, the hook takes any later word for a program too.
  It also reads what `bash -c` and `eval` run and the value of an alias.
  The subcommand is the first word after the script's path that is not `--`, and the call counts when a variable or a substitution hides that word, when `xargs` runs the script, and when a shell reads its commands from a heredoc, a here-string or a pipe in a command that names the script.
  So `ruff check`, `cp` or `grep` of the script runs, and so does a shell that runs a script file whose path holds no variable or substitution.
  It fails closed.
  It denies a command that names tofu and that it cannot read, and says why, when `shfmt` is not on its PATH, when the command parses neither as bash nor as zsh, and when a variable or a substitution decides the program, the subcommand or a flag that would make it write.
  It never sees a program that runs tofu as a process of its own, such as a script file, `make`, a devenv task or the script of `live-mutation`, which runs every command of a proposal that way.
  `tests/hooks.sh` runs the hook with a PATH of the baseline's `lyngon.scriptTools` and nothing else, and once with `python3` and no `shfmt`.
- `PreToolUse` on `Edit`, `Write`, `NotebookEdit` and `Bash`, named in the frontmatter of `auto`: `hooks/lead-writes-no-code.py` refuses the lead a write of a file inside a repository, outside `tmp/`, `docs/plans/` and `docs/mistakes/`, and names the `build:implementer` delegate that writes it instead.
  Claude Code registers a hook of a skill's frontmatter when the skill starts, and runs it in that session's lead from then on, after a compaction too, and never in a subagent, whose hook input holds an `agent_id` (measured on Claude Code 2.1.283 and 2.1.299).
  A session without the mode never runs the hook, and neither does a session resumed in a new process, which drops it.
  The hook reads a shell command in Python alone, with `may_run` of `hooks/shell_syntax.py` and `hooks/shell_writes.py`, so it decides the same whatever the PATH that Claude Code gives its hooks holds.
  It refuses the writes it can name before the command runs: a redirection with `>`, `>>`, `>|`, `&>`, `&>>` or `<>`, or with `>&` to any word but a number or `-`, as in `>&run.log`, and the files that `sed -i`, `perl -i`, `tee`, `cp`, `mv`, `rm` and `touch` write, also inside a substitution, backquotes or a loop and when `find` or `xargs` runs one of them.
  It takes every word of a simple command for a possible command name, so it also refuses such a writer after a keyword or behind a program that starts it, as in `sudo rm`, and `git rm` and `git mv` of a file of the change.
  A path that holds a variable or a substitution, and the files that `find` or `xargs` hands over, count as files of the change.
  `$TMPDIR` and `${TMPDIR}` are the exception: such a path counts as the path under the hook's own TMPDIR, as long as that is an absolute path that bash neither splits nor globs and the command names TMPDIR nowhere else, as an assignment or `${TMPDIR:-x}` would.
  Claude Code gives the shell that TMPDIR, or under its sandbox a directory inside it, and its sandbox tells the model to put temporary files there (measured on Claude Code 2.1.325).
  A relative path resolves from the session's working directory, and a `cd` in the command does not move it.
  It refuses a command that it cannot read, and its reason names the construct, such as a quote that is not closed, a here-document without its end line, a case statement inside parentheses, or a quote inside `${...}` or an arithmetic expression.
  Any other program may write too, such as an interpreter, git, a formatter, `ln`, `patch` or `find -delete`, or a writer that `bash -c` or `eval` starts, and the hook lets it run, since it cannot tell its write from a read; there the mode's text holds the rule.
  `tests/hooks.sh` runs it with `python3` alone on the PATH.
- `PreToolUse` on `Edit`, `Write`, `NotebookEdit` and `Bash`: `hooks/auditor-deletes-only-comments.py` refuses the agent `build:comment-auditor` an edit inside a repository that changes code, so the code that a deleted comment covered for stays for `clean-comments` to fix, also when it never runs.
  It acts on the calls whose hook input names that agent as `agent_type`, which Claude Code sets in a subagent's calls and leaves out of the lead's (measured on Claude Code 2.1.322).
  It lexes the file before and after the call with `pygmentize`, leaves out the comments and the docstrings, and refuses the call when the code that remains differs in a token, in the space between two tokens or in the indentation of a line.
  A comment may go with the space around it, and a blank line with it.
  The reason names the first line of code that changed and tells the auditor to mark that code `MUST KILL` instead.
  Pygments takes each triple-quoted Python string that starts a line for a docstring, so the hook lets the auditor delete one that is not.
  It lexes an HTML comment in Markdown as text, so the hook refuses the auditor the deletion of one.
  It lexes a shebang as a comment, and the hook keeps it as code that ends at its line break, so the auditor may delete the comment right under a shebang and may not change the shebang.
  It fails closed: it refuses an edit that it cannot check, of a notebook, of a file that is not UTF-8 or whose name Pygments knows no language of, and every edit when `pygmentize` is not on its PATH, and the reason tells the auditor to leave those comments and report them skipped.
  Of the auditor's shell commands it refuses each write into a repository that `hooks/shell_writes.py` names, the same writes that `hooks/lead-writes-no-code.py` refuses the lead, and lets any other program run.
  `tests/hooks.sh` runs it with a PATH of the baseline's `lyngon.scriptTools` and nothing else, and once with `python3` and no `pygmentize`.
- `Stop`, named in the frontmatter of `auto`: `hooks/reply-has-no-dash.py` sends a reply of the lead back once when its prose holds an em dash or an en dash, which the mode's rules for the reply forbid, and quotes the lines that hold one. Code, fenced or inline, is left out, since the mode asks for some output verbatim. Claude Code gives the hook the reply as `last_assistant_message`, and the reply written after the block ends the turn whatever it holds, so a dash the lead cannot remove ends no session in a loop (measured on Claude Code 2.1.283 and 2.1.299). It runs where the hook on writes runs, and `tests/hooks.sh` runs it with a PATH of the baseline's `lyngon.scriptTools` and nothing else.

## The mistake ledger

`correction` keeps one file per mistake under `docs/mistakes/` of the repository it works in, and `validate-documents` of the baseline checks the shape of each.
Its script `skills/correction/scripts/prune-mistakes.py` deletes the files whose date is older than the baseline option `lyngon.mistakes.maxAgeDays`, 365 days by default.
The script is Python and imports the standard library only, because the baseline option `lyngon.scriptTools`, `python3`, `pygmentize`, `shfmt` and `git` by default, is all a shipped script may run.
The commands that a script runs for the repository, such as the `tofu` of a live mutation, come from the repository's shell.
`tests/prune-mistakes.sh` runs it with a PATH that holds those tools and nothing else, and `tests/work-trace.sh` and `tests/live-mutation.sh` run the scripts of `work-trace` and `live-mutation` the same way.
The OpenTofu cases of `tests/live-mutation.sh` add `tofu` after those tools, and run it against git repositories with a bare origin.

## Install

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install build@lyngon --scope project
```
