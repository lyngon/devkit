# build

How a change is built and handed over in a Lyngon repository: a prompt or an issue in, proof and a pull request out.

## Skills

- `/build:auto <task>`: the mode for one task, which only the operator starts. It routes the task to a playbook under `skills/auto/playbooks/` (feature, refactoring, bug fix, prototype, autonomous run) or to `figure-it-out`, delegates code to the agent `build:implementer` (`agents/implementer.md`) and holds every claim of the reply to its evidence.
- `/build:pull-request [change]`: hand a finished change over as one pull request, with the comments cleaned, the full check green on the pushed head, a title and a body that `check-pull-request` accepts, and the branch's work trace posted on it. The agent invokes it whenever a change is done.
- `/build:tdd [bug]`: fix a bug test first when a cheap test path exists, with the failing test committed before the fix and kept, and no test rather than a bad one.
- `/build:correction [mistake]`: record a mistake in the mistake ledger, one file under `docs/mistakes/`, and fix a mistake that repeats at the highest level that works: architecture, then types, then a lint, then a test, and a rule file last. The agent invokes it when the operator corrects it, a review finding is accepted or a change is reverted.
- `/build:architect <task>`: design before code. Ground the design with `discover:how`, sketch at least two structurally distinct candidates through `arena`, write the chosen sketch and its rationale into the design file under `docs/plans/`, then build against it, or stop there when the owner asked for a gate on the design.
- `/build:arena <task>`: run two or more candidates at the same task in parallel, score them against a rubric beside a judge on another model, pick a base and graft the best of the others into it. The candidates and the synthesis note live in a worktree or under `tmp/arena/` and are never committed.
- `/build:review [change]`: an adversarial review of a change by reviewers on different models, each with the same prompt, rubric and code-quality lens, judged into one verdict (act on, consider, noted, dismissed). It changes nothing.
- `/build:figure-it-out <task>`: for work that no narrower skill fits, such as a large migration. Frame a falsifiable definition of done and a rigor level, write a phase list with the verification harness first into the design file under `docs/plans/`, then run each unit as an experiment that is kept or reverted, with the trail in `work-trace`.
- `/build:work-trace [task]`: keep a decision trail of long or unattended work, one row per decision with its evidence, in `tmp/work-trace/<branch>.tsv`, written by the script `skills/work-trace/scripts/trace.py`. It is checked against the session's transcript and scanned by a reviewer on another model, whose Attention section lies beside it. It is never committed, and `pull-request` posts both on the pull request.
- `/build:benchmark [claim]`: vet a performance number before it is reported or acted on, with seven questions answered from runs (the limiter, tuning, limits, errors, repeatability, relevance, and whether the work happened), and report the verdict with the run count, the range and the limiter.
- `/build:clean-comments [scope]`: before a change goes to a pull request, have the agent `build:comment-auditor` (`agents/comment-auditor.md`) delete the comments of the change that its exceptions do not protect and flag the code they covered for, then vet its work, fix the flags at their root and encode each constraint a comment claimed.

The agent never starts `auto`, which carries `disable-model-invocation: true`.
It starts `architect`, `arena`, `review` and `figure-it-out` only when the operator asks for one of them, or when `auto` routes there or `architect` runs `arena` and `review`.
Each of the four spawns several subagents, directly or through the others.
The agent starts every other skill on its own trigger.

The skills and the agents are vendored from [pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT), all but the script of `correction`, and the hooks are written by Lyngon.
Upstream, `auto` is called `poteto-mode`, `pull-request` is its playbook `opening-a-pr`, `correction` is `correct`, `review` `interrogate`, `work-trace` `show-me-your-work`, `benchmark` `benchmark-checklist`, `clean-comments` `no-comments`, `implementer` poteto-agent and `comment-auditor` Comment Sicko.
The license is `LICENSE-pstack` in this plugin, and the provenance record is [pstack.md](../../catalog/vendored/pstack.md) under `catalog/vendored/`.

## Hooks

- `SessionStart`: prints `hooks/standing-instructions.txt`, the standing instructions, at the start of every session and again after each compaction, with the path of the mode's file filled in. `validate-marketplace` fails the text above 4,000 characters, since every session pays for it, and the mode's `SKILL.md` above 15,000 characters or without `disable-model-invocation: true`. `tests/hooks.sh` runs the hook with nothing but bash on the PATH.
- `PreToolUse` on `Agent`: `hooks/agent-in-the-foreground.py` gives a call that leaves `run_in_background` out the value `false`, so that its subagent starts in the foreground, where a headless session would start it in the background. Claude Code runs the changed input in place of the one the model wrote, and the trace still shows the model's (measured on Claude Code 2.1.283 and 2.1.299). A call that names the parameter runs as it is. With the fork subagent of an interactive session, which starts every subagent in the background, the call starts as it would without the hook (measured with `CLAUDE_CODE_FORK_SUBAGENT=1` in a headless session). `tests/hooks.sh` runs the hook with a PATH of the baseline's `lyngon.scriptTools` and nothing else.
- `PreToolUse` on `Edit`, `Write` and `NotebookEdit`, named in the frontmatter of `auto`: `hooks/lead-writes-no-code.py` refuses the lead a write of a file inside a repository, outside `tmp/`, `docs/plans/` and `docs/mistakes/`, and names the `build:implementer` delegate that writes it instead. Claude Code registers a hook of a skill's frontmatter when the skill starts, and runs it in that session's lead from then on, after a compaction too, and never in a subagent, whose hook input holds an `agent_id` (measured on Claude Code 2.1.283 and 2.1.299). A session without the mode never runs the hook, and neither does a session resumed in a new process, which drops it. The hook sees no command of the shell. `tests/hooks.sh` runs it with the same PATH.

## The mistake ledger

`correction` keeps one file per mistake under `docs/mistakes/` of the repository it works in, and `validate-documents` of the baseline checks the shape of each.
Its script `skills/correction/scripts/prune-mistakes.py` deletes the files whose date is older than the baseline option `lyngon.mistakes.maxAgeDays`, 365 days by default.
The script is Python and imports the standard library only, because the baseline option `lyngon.scriptTools` is all a shipped script may run.
`tests/prune-mistakes.sh` runs it with a PATH that holds those tools and nothing else, and `tests/work-trace.sh` runs the script of `work-trace` the same way.

## Install

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install build@lyngon --scope project
```
