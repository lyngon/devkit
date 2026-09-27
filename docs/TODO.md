# TODO

Deferred work the owner explicitly chose not to do yet.
One item per line, with the date it was deferred.

- 2026-09-27: Reserve "domain" in `STRUCTURE.md`'s word rules. Mark "domain" as meaning the domain layer of a Context and never a DNS name, and use "domain name", "Zone" and "Hostname" for DNS related concepts. Every infrastructure repository will hit this, and the conventions plugin would then enforce it everywhere.

- 2026-09-27: Fix the init template's `.claude/settings.json`. Enabling only `all@lyngon` left build unloaded with an unmet dependency. Either list every plugin in the template, or fix how all declares its dependencies.

- 2026-09-27: Fix the Terraform row in the init skill's `devenv.md`.
  - git-hooks.nix's `tflint` hook passes file names, which tflint dropped in v0.47.
  - Ship a per-directory wrapper, as per example `tmp/other-projects-devenv.nix`, with `tflint.withPlugins` for the AWS ruleset (no downloads in CI).
  - Default to `languages.opentofu.`

- 2026-09-27: Generalize infra in `STRUCTURE.md`.
  - Its "one root per environment" rule doesn't fit a multi-account organization.
  - A directory of roots per environment, plus a foundation tier for account-level roots, could become the documented option.
  - The validator could then learn `infra/foundation/`.

- 2026-09-27: Add a roadmap document for multi-piece work to `discover:approach`.
  - When it decomposes work into pieces, there's no first-class place for the order and shared facts.
  - `build:finish` deletes plan files, so a project repository needed a hand-made overview file and a record kept in a commit message.
  - A `docs/plans/<date>-<slug>-roadmap.md` that `build:finish` knows to keep would fix that.

- 2026-09-27: Add first-class support to `build:delegate` for two task shapes this run needed rulings for.
  - Tasks that produce only uncommitted files: review-package assumes a git diff.
  - A task the owner must perform, such as an irreversible step: an explicit "owner task" type that stops the executor, keeps the ledger, and resumes into `build:finish`.

- 2026-09-27: Brief reviewers on facts that changed during the session. The final reviewer flagged a "Critical" from a stale inventory: your deletion of the login profile had happened after the inventory. A "state changes since the inputs were collected" block in the reviewer templates would prevent that.

- 2026-09-27: Keep owner-facing commands shell-agnostic. Add a line to the conventions or `build:plan`: commands a person runs by hand avoid bash-only syntax such as `PIPESTATUS`, or run through bash.

- 2026-09-26: Somehow make claude more cognizant to context window. I want context window usage to remain under 50% (ideally under 40%). Can Claude estimate ahead of task how much context window might be used, and suggest how and where in the process to break things up into logical "checkpoints", each starting with a clear context window. (Not sure about this one)

- 2026-09-26: A skill for wrapping up sessions (`conclude`?), requesting Claude to:
  - Make sure documents are up-to date, and repo / branch in a clean state.
  - Suggest prompts for continuing work (if any) in new session (writing a hand-over document if a lot of context is needed).
  - Suggest process improvements, E.g. update misleading or suboptimal `devkit` skills.
  - Provide "personal" feedback of how the session was. What was "enjoyable" or "not-so-enjoyable".

- 2026-09-26: Instruct Claude to end every turn with clear suggested (options for) next actions.

- 2026-09-15: Make the marketplace agent-agnostic (Codex, Cursor, Copilot) once a second agent is in use at Lyngon. Skill bodies are already written agent-neutral to keep this cheap.

- 2026-09-15: `/devkit:bump-skill`: compare a vendored skill with upstream between the commit in `UPSTREAM.md` and the latest, decide what to carry over, apply it, update the record. Reviews against `shared/SKILL-REVIEW.md`.

- 2026-09-16: `/devkit:package`: build a zip per skill as a release artifact (a devenv task run in CI), so skills can be uploaded to Claude.ai chat, which takes skill folders as zip files and has no plugin or marketplace support. Skills that call other skills by `plugin:name` or rely on Bash need a note on what breaks there.

- 2026-09-20: Verify that the `validate-structure` hook fires in a repository that imports `lyngon/devenv` remotely; only the devkit's own `./devenv` import has been exercised. How: in a scratch repository outside the devkit, write a `devenv.yaml` with the `lyngon` input as `github:lyngon/devkit` (or `path:/home/anders/Projects/devkit` for a first local pass) and `flake: false`, import `lyngon/devenv`, set `lyngon.enable = true`, then `devenv shell` and check that `.pre-commit-config.yaml` lists `validate-structure` with a store-path entry. Then add `libs/foo/pyproject.toml` and a root `pyproject.toml` listing it, `git add`, `git commit`: the hook must fail with `missing INTENT.md`. Add `README.md`, `INTENT.md`, `CLAUDE.md` and the `AGENTS.md` symlink and commit again: it must pass. Finish with `devenv test`. Repeat with the GitHub form of the input before relying on it.

- 2026-09-20: Linter configurations as `add-package` templates. The `conventions` plugin ships prose only; every rule a linter can check (an organization ruff rule set and mypy strictness for Python, `tsconfig` strict options and an eslint configuration for TypeScript, `deadnix` and `statix` for Nix) belongs in the linter, written into a new package's manifest by `/repo:add-package` from templates in its references, with the hook enabled in the package's `devenv.nix`. Do this once the prose conventions have settled what the linters should check; each convention skill's "checked by" line then names the hook.

- 2026-09-23: The `SessionStart` hook that tells agents which skills to invoke lives in `repo`, so a repository that installs only `core` gets no flow guidance. Move the generic lines (brainstorm, approach, build, practice, review, unslop, the `WORKFLOW.md` pointer) to a plugin that is in `core`, keeping only the structure line in `repo`; a bundle cannot carry a hook, since the validator treats a plugin with components as not a bundle.
