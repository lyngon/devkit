# Review on the pull request

Seed prompt for a fresh Claude Code session in the devkit repository.

Start by invoking the `discover:approach` skill with this brief as the request.
The direction is settled by the owner; the open questions below are about where the rules live and how each skill changes.
Expect an ADR that amends ADR 0016.

## The decision (owner, 2026-09-29)

In this repository and in every repository that uses the devkit plugins:

- The agent commits on a feature branch whenever it is convenient, without asking and without waiting for a file review, one commit per concern in Conventional Commits form.
- Once the work is done and the full check passes, the agent pushes the branch and opens a pull request without asking.
- The owner reviews the pull request.
  Merging stays the owner's decision.

Limits the agent proposed and the owner has not yet confirmed; settle them in the interview:

- Commits go on a feature branch only; on the default branch, the agent creates a branch first.
- The full check passes before every push; a hook is never bypassed (`--no-verify` or a disabled hook).
- History that has been pushed is not rewritten (rebase, amend, force-push) without asking; fixes after a push are new commits.
- No merge, no push to the default branch, no tag, release or publish without asking.
- Without a remote or a forge CLI, the agent commits and reports, and skips the push and the pull request.

## Why

ADR 0016 already removed per-commit review for planned work: the executor commits per task and the owner reviews the plan and the finished branch.
Interactive sessions without a plan kept the older habit (its Consequences: "stage, run the full check, stop for file review, commit when told").
That habit makes the owner the bottleneck again, and it produces worse history.
In the session that fixed the init templates (pull request 2, 2026-09-29), holding every commit until review left one working tree with twelve concerns mixed together.
The agent then had to rebuild twelve commits after the fact by restoring files to HEAD and replaying edits in order, after Claude Code's auto mode refused `git checkout -- .` as destructive.

## Facts

Where the old habit is written today:

- `docs/adr/0016-planned-work-is-reviewed-at-two-gates.md`, Consequences, first bullet.
- `shared/WORKFLOW.md` (symlinked into `build:plan` and `discover:approach`):
  - The bounded change flow has no commit or push step, and step 5 hands the branch to `/build:finish`.
  - Gate 2 of the architectural flow says the user "merges, asks for changes or keeps it".
  - "Who decides what" stops an executor for "a push to a shared branch"; a feature branch the agent created is not shared, and the text should say so.
- `plugins/build/skills/finish/SKILL.md`, Step 5: the integration menu (merge locally, push and create a pull request, keep) and "Wait for their answer; the integration decision is theirs".
  The skill is vendored, so every change is listed under "Local patches" in its `UPSTREAM.md`.
- `plugins/repo/skills/init/SKILL.md`, step 7: "Do not commit and do not stage", then offer `chore: initialize repository` and wait.
- `plugins/repo/skills/add-package/SKILL.md`, step 7: "Do not commit and do not stage", then offer `feat(<name>): add <kind> <name>`.
- `plugins/devkit/skills/add-skill/SKILL.md` (two places), `references/install.md` and `references/create.md`: "Do not commit", offer a message.
- Seed prompts carry the line "Do not commit until I have reviewed the files; after the review, commit by concern in Conventional Commits form" (today in `docs/seed-prompts/session-environment-hooks.md`).

Constraints:

- Claude Code's default instructions say to commit or push only when the user asks.
  A standing authorization overrides that only if it is in the agent's context in every repository that uses the devkit, not only in this one.
  CLAUDE.md is not the place: organization-wide conventions come from plugins and are never copied into a repository's CLAUDE.md.
  Candidates: `shared/WORKFLOW.md` (read only when a skill that links it loads), `conventions:engineering` (loaded by path for every file), and the `repo` plugin's `SessionStart` hook text (only in repositories with `repo` installed; `docs/TODO.md` already defers moving its generic lines to a plugin in `core`).
- `practice:verify` requires evidence before committing, pushing or opening a pull request; that stays.
- `docs/seed-prompts/owner-gates.md` also amends the stop list in ADR 0016 and `WORKFLOW.md`; keep the two changes consistent, whichever lands second.
- `docs/seed-prompts/conclude-skill.md` places the wrap-up skill "after the integration choice, before the push"; with an automatic push, say where it runs instead.

## Decisions to settle in the interview

1. Where the standing authorization lives so that it reaches every repository, and its exact wording.
2. `build:finish`: whether the menu becomes a default (push and open a pull request) with merging locally and keeping the branch as options on request, and what it does with the worktree and plan workspace after it opens the pull request.
3. `init`: a fresh repository has no default branch yet, so is the first commit on the default branch or on a branch with a pull request? And in adopt mode, a branch and a pull request?
4. `add-package` and `add-skill`: commit on their own, and on which branch.
5. Commit granularity in interactive work: a commit per concern as the work goes, with a plugin's version bump and `CHANGELOG.md` entry in the same commit, as this repository's history already does.
6. Whether `review:request` runs before the pull request is opened in the bounded flow (it is step 4 today), and whether its findings go into the pull request description.
7. What every pull request description carries: the rulings and deferred minors, the verification output, and anything the owner must decide.
8. The standard lines of a seed prompt, and whether a template for them belongs in `docs/seed-prompts/` or `CLAUDE.md`.

## Out of scope

- Owner gates for operational tasks: `docs/seed-prompts/owner-gates.md`.
- Merging without the owner, auto-merge, and CI changes.

## Working rules for this session

Once the owner approves the design, follow the new practice already: branch `feat/review-on-the-pull-request`, commit per concern as you go, bump the version and add a `CHANGELOG.md` entry of every plugin you change, run `devenv test`, then push and open the pull request.
Remove this file and its `docs/TODO.md` entry in the last commit.
