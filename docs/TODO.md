# TODO

Deferred work the owner explicitly chose not to do yet.
One item per line, with the date it was deferred.
A queued item has a seed prompt in `docs/seed-prompts/`: paste the file into a fresh session to start the work, and remove the file with the entry when the work lands.
Queued items are listed in the order to implement them; a new one is placed by its dependencies and impact, not by date.

## Queued

The first five are the remaining pieces of the philosophy overhaul, in order; what is settled for each is in [the roadmap](plans/2026-10-07-philosophy-overhaul-roadmap.md).

- 2026-10-07: [Workflow](seed-prompts/003-workflow.md), a design through `discover:approach`. The gated workflow and the nine superpowers skills are replaced by skills vendored from pstack.
- 2026-10-07: [Agent identity](seed-prompts/004-agent-identity.md), a design through `discover:approach`. Agents act as an organization-owned GitHub App.
- 2026-10-07: [Issue pipeline](seed-prompts/005-issue-pipeline.md), a design through `discover:approach`. Filing, triage and picking on GitHub Issues, replacing this file.
- 2026-10-07: [GitHub repository setup](seed-prompts/006-github-repository-setup.md), a design through `discover:approach`. `repo:init` emits the ruleset, CODEOWNERS, labels, issue forms and merge settings.
- 2026-10-07: [Rules as checks](seed-prompts/007-rules-as-checks.md), a design through `discover:approach`, then one bounded change per check. Every rule a tool can decide moves from prose into a check.
- 2026-09-27: [Roadmap for multi-piece work](seed-prompts/roadmap-for-multi-piece-work.md), a design through `discover:approach`. A place for the order of the pieces and the facts they share when a design splits work into pieces, kept until the last piece lands.
- 2026-09-26: [Session wrap-up skill](seed-prompts/conclude-skill.md), a design through `discover:approach`. Documents up to date and a clean branch, prompts for continuing, process improvements as a paste-ready devkit prompt that extends this file, and feedback on the session; run by hand at the end of a lyngon.com session on 2026-09-27, which settled where it sits (after the integration choice, before the push).

## Deferred

- 2026-09-29: Rethink the process for deferred items: possibly a skill that writes a `docs/TODO.md` entry and, for a queued item, its seed prompt with the standard lines from `.claude/rules/work-in-progress-files.md`.
- 2026-09-27: Generalize infra in `STRUCTURE.md` for a multi-account organization: a directory of roots per environment plus a foundation tier for account-level roots (`infra/foundation/`), which the validator would then learn. The validator does not reject that directory today, only the prose disagrees; wait for a second repository with account-level roots before generalizing from one.
- 2026-09-27: An OpenTofu convention skill (`conventions:opentofu`): a backend and provider template, lock files for `linux_amd64` and `darwin_arm64`, `*_override.tf` and module lock files ignored, `prevent_destroy`. The source is lyngon.com's `docs/conventions/roots.md`; promote it after the second infrastructure repository, when the rules have settled.
- 2026-09-26: Somehow make claude more cognizant to context window. I want context window usage to remain under 50% (ideally under 40%). Can Claude estimate ahead of task how much context window might be used, and suggest how and where in the process to break things up into logical "checkpoints", each starting with a clear context window. (Not sure about this one)
- 2026-09-26: Instruct Claude to end every turn with clear suggested (options for) next actions.
- 2026-09-15: `/devkit:bump-skill`: compare everything vendored from one upstream between the commit in its record, `catalog/vendored/<upstream>.md`, and the latest, decide what to carry over, apply it, update the record. Reviews against `shared/SKILL-REVIEW.md`.
- 2026-09-16: `/devkit:package`: build a zip per skill as a release artifact (a devenv task run in CI), so skills can be uploaded to Claude.ai chat, which takes skill folders as zip files and has no plugin or marketplace support. Skills that call other skills by `plugin:name` or rely on Bash need a note on what breaks there.
- 2026-09-20: Verify that the `validate-structure` hook fires in a repository that imports `lyngon/devenv` remotely; only the devkit's own `./devenv` import has been exercised. How: in a scratch repository outside the devkit, write a `devenv.yaml` with the `lyngon` input as `github:lyngon/devkit` (or `path:/home/anders/Projects/devkit` for a first local pass) and `flake: false`, import `lyngon/devenv`, set `lyngon.enable = true`, then `devenv shell` and check that `.pre-commit-config.yaml` lists `validate-structure` with a store-path entry. Then add `libs/foo/pyproject.toml` and a root `pyproject.toml` listing it, `git add`, `git commit`: the hook must fail with `missing README.md`. Add `README.md` and commit again: it must pass. Finish with `devenv test`. Repeat with the GitHub form of the input before relying on it.
- 2026-09-20: Linter configurations as `add-package` templates. The `conventions` plugin ships prose only; every rule a linter can check (an organization ruff rule set and mypy strictness for Python, `tsconfig` strict options and an eslint configuration for TypeScript, `deadnix` and `statix` for Nix) belongs in the linter, written into a new package's manifest by `/repo:add-package` from templates in its references, with the hook enabled in the package's `devenv.nix`. Do this once the prose conventions have settled what the linters should check; each convention skill's "checked by" line then names the hook.
