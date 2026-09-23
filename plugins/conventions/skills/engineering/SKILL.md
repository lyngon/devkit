---
name: engineering
description: Lyngon engineering conventions that apply to every file in every repository. Background knowledge, loaded automatically while working on any file.
user-invocable: false
paths:
  - "**/*"
---

# Engineering conventions

Rules for every change in a Lyngon repository.
Language-specific rules load with the file's language; document rules load with the document.

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

## Handing over

- Run the repository's full check before handing over. Never disable or skip a check to make it pass.
- Report faithfully: failing tests with their output, skipped steps by name, done things plainly.
- Commit messages follow Conventional Commits, one concern per commit.

## With devenv

- The environment is `devenv.nix`; the full check is `devenv test`, which runs every git hook on every file. Never disable a hook.
- Secrets are declared in `secretspec.toml`.

## With the Lyngon structure

- Packages are created with `/repo:add-package`, never by hand.
- Dependencies between layers point inward; an app holds main, wiring and config and no logic.
- One workspace and one lockfile per language at the repository root; `validate-structure` checks the layout on every commit.
