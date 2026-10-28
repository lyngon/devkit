# build

From an approved design to an open pull request.

## Skills

- `/build:plan`: write the implementation plan for a settled design as the tasks in order with their interfaces, acceptance lines and dictated text, written for an implementer who writes the tests and the code, appended to the design file under `docs/plans/`, and hand it to the user for review.
- `/build:delegate`: execute a plan with a fresh implementer subagent per task, a spec-and-quality review after each task and a whole-branch review at the end. The default for more than a handful of tasks.
- `/build:execute`: execute a plan yourself in the session, task by task, with one whole-branch review at the end. The cheap mode.
- `/build:finish`: run the full check, remove the plan file, push the branch and open the pull request (asking once first, unless the user's standing instructions cover it, as the `conventions` plugin's do), then offer the deferred findings for `docs/TODO.md`; merging locally or keeping the branch only on request.
- `/build:correction [mistake]`: record a mistake in the mistake ledger, one file under `docs/mistakes/`, and fix a mistake that repeats at the highest level that works: architecture, then types, then a lint, then a test, and a rule file last. The agent invokes it when the operator corrects it, a review finding is accepted or a change is reverted.
- `/build:architect <task>`: design before code. Ground the design with `discover:how`, sketch at least two structurally distinct candidates through `arena`, write the chosen sketch and its rationale into the design file under `docs/plans/`, then build against it, or stop there when the owner asked for a gate on the design.
- `/build:arena <task>`: run two or more candidates at the same task in parallel, score them against a rubric beside a judge on another model, pick a base and graft the best of the others into it. The candidates and the synthesis note live in a worktree or under `tmp/arena/` and are never committed.
- `/build:review [change]`: an adversarial review of a change by reviewers on different models, each with the same prompt, rubric and code-quality lens, judged into one verdict (act on, consider, noted, dismissed). It changes nothing.
- `/build:figure-it-out <task>`: for work that no narrower skill fits, such as a large migration. Frame a falsifiable definition of done and a rigor level, write a phase list with the verification harness first into the design file under `docs/plans/`, then run each unit as an experiment that is kept or reverted, with the trail in `work-trace`.
- `/build:work-trace [task]`: keep a decision trail of long or unattended work, one row per decision with its evidence, in `tmp/work-trace/<task>.tsv`, written by the script `skills/work-trace/scripts/trace.py`. It is checked against the session's transcript, scanned by a reviewer on another model, and posted on the pull request when a reviewer needs it, never committed.
- `/build:benchmark [claim]`: vet a performance number before it is reported or acted on, with seven questions answered from runs (the limiter, tuning, limits, errors, repeatability, relevance, and whether the work happened), and report the verdict with the run count, the range and the limiter.
- `/build:clean-comments [scope]`: before a change goes to a pull request, have the agent `build:comment-auditor` (`agents/comment-auditor.md`) delete the comments of the change that its exceptions do not protect and flag the code they covered for, then vet its work, fix the flags at their root and encode each constraint a comment claimed.

The agent starts `architect`, `arena`, `review` and `figure-it-out` only when the operator asks for one of them, or when `architect` runs `arena` and `review`.
Each of the four spawns several subagents, directly or through the others.

The user reviews at two review gates: the plan before execution, and the pull request afterwards, starting from the executor's "Rulings I made", "Deferred minors" and "Owner gates" lists in its description.
Between them the executor commits per task on a feature branch and stops only at owner gates: the ones the plan declares, each of which the user may pre-approve by its ID when approving the plan, and the stop conditions every executor carries.
Every task with an owner gate ends with a record commit that holds its evidence.
The execution ledger and the task briefs live under `tmp/build/<plan>/`, the agent scratch directory; when a run pauses, the ledger is copied into the plan, so a later session resumes it.
See the decision records [Planned work is reviewed at two gates](../../docs/decisions/planned-work-is-reviewed-at-two-gates.md), [Owner gates are declared in the plan and pre-approved by name](../../docs/decisions/owner-gates-are-declared-in-the-plan-and-pre-approved-by-name.md) and [Plans carry decisions and facts; the implementer writes the tests and the code](../../docs/decisions/plans-carry-decisions-and-facts-the-implementer-writes-the-tests-and-the-code.md).

`plan`, `delegate`, `execute` and `finish` are vendored from [obra/superpowers](https://github.com/obra/superpowers) (MIT), and `correction`, `architect`, `arena`, `review`, `figure-it-out`, `work-trace`, `benchmark`, `clean-comments` and the agent `comment-auditor` from [pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT), where `correction` is called `correct`, `review` `interrogate`, `work-trace` `show-me-your-work`, `benchmark` `benchmark-checklist`, `clean-comments` `no-comments` and `comment-auditor` Comment Sicko.
The licenses are `LICENSE-superpowers` and `LICENSE-pstack` in this plugin, and the provenance records are [superpowers.md](../../catalog/vendored/superpowers.md) and [pstack.md](../../catalog/vendored/pstack.md) under `catalog/vendored/`.
The executors invoke `practice:tdd`, `practice:debug`, `practice:verify` and `review:request`, skills of two other members of the `all` bundle.

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
