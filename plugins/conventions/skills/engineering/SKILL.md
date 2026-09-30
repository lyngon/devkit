---
name: engineering
description: Lyngon engineering conventions for every change in every repository, covering how to decide, change, test, commit, push and open pull requests. Invoke before any engineering work, before the first edit of a session.
user-invocable: false
paths:
  - "**/*"
---

# Engineering conventions

Rules for every change in a Lyngon repository.
Language and document rules are separate skills: invoke the one for a file's kind before editing it.

## Deciding

- Weigh decisions toward final quality: simplicity, robustness and long-term maintainability. Give little weight to development cost.
- Simplicity is part of quality. No speculative abstraction, no configuration for a case nobody has.
- A library declares dependency constraints, never pins. The lockfile of the workspace or the deployable pins.

## Changing

- Start a bug fix by reproducing the bug end to end, as close to how a user meets it as possible. Keep the reproduction as a regression test where practical.
- Never edit a generated file; change its source or generator. `generated/` and `vendor/` directories are not yours.
- Never write a secret (key, token, password) into code, configuration or a commit. Secrets are supplied out of band.
- Every tool comes from the repository's declared environment. When one is missing, add it there; never install imperatively.
- Flag an unrelated problem when you meet one. Fix it too when the fix is small, in a separate commit.

## Testing

- Test through the public interface of the package. A test that reaches into private modules breaks on every refactor.
- Prefer real collaborators and fakes over mocks of your own code. Mock only what crosses the process boundary.
- A flaky test is a bug. Fix it or delete it; never retry it.

## Committing and handing over

These are the user's standing instructions: they count as being asked to commit, push and open a pull request.

- Work on a feature branch named `<type>/<slug>`, after the Conventional Commits type of its main change. On the default branch, create one first. When the current branch carries other work (its pull request is open or merged, or it is named for another change), start a new branch from the up-to-date default branch.
- Commit without asking whenever a concern is done: one concern per commit, in Conventional Commits form. Commit messages use no em or en dashes and no curly quotes. Commits not yet pushed may be amended or reordered.
- When the work is done and the full check passes, push the branch and open a pull request without asking. The user reviews the pull request and decides the merge.
- Run the full check before every push. Never disable, skip or weaken a check or hook to get past it.
- Never rewrite pushed history without asking; fixes after a push are new commits.
- Ask before any other effect outside the branch: a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish. An owner gate that a plan declares and the user pre-approved by its ID counts as asking.
- Without a remote, commit and report. With a remote but no forge CLI, push and hand over the pull request link the forge printed.
- Report faithfully: failing checks with their output, skipped steps by name, done things plainly.

## With devenv

- The environment is `devenv.nix`; the full check is `devenv test`, which runs every git hook on every file. Never disable a hook.
- Secrets are declared in `secretspec.toml`.

## With the Lyngon baseline

Commit messages are checked by the `commitizen` and `prose-lint-commit-msg` hooks.

## With the Lyngon structure

- Packages are created with `/repo:add-package`, never by hand.
- Dependencies between layers point inward; an app holds main, wiring and config and no logic.
- One workspace and one lockfile per language at the repository root; `validate-structure` checks the layout on every commit.
