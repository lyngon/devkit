# Repo plugin: init templates and devenv 2.4

Seed prompt for a fresh Claude Code session in the devkit repository.

Fix six defects in the `repo` plugin's templates, found by three Claude Code sessions in an infrastructure repository (lyngon.com) on 2026-09-27.
Every claim below was checked against this repository's source, the pinned git-hooks.nix and a live devenv 2.3.1 on 2026-09-27.

This is a bounded change: no design file and no plan file.
Work on a branch named `fix/repo-init-templates`.
Do not commit until I have reviewed the files; after the review, commit by concern in Conventional Commits form.
Bump the `repo` plugin version (user-visible changes) and add a `CHANGELOG.md` entry.
Run `devenv test` before handing over and report its output faithfully.

## 1. `.claude/settings.json` lists every plugin

Facts: Claude Code 2.1.278.
In lyngon.com, `all@lyngon` was installed at project scope and its seven dependencies were auto-installed at project scope (`"auto": true` in `~/.claude/plugins/installed_plugins.json`).
After a restart, `build:plan` failed with "Unknown skill: build:plan. 1 plugin did not load in this session (unmet dependency)", naming neither the plugin nor the dependency, while the skills of `practice` and `review` (the dependencies of `build`) were present.
The Claude Code docs say that installing a plugin installs and enables its dependencies at the same scope, and are silent on the dependencies of a dependency.
So an auto-installed dependency does not count as enabled when a dependency's own dependency list is checked.
It works on this machine only because every lyngon plugin is also installed at user scope.
Listing every plugin in the project's `enabledPlugins` is the known workaround.

Change:

- The template under `## .claude/settings.json` in `plugins/repo/skills/init/references/repo-files.md` enables `all@lyngon` and each of its dependencies by name, with a sentence saying why.
- `scripts/validate-marketplace.sh` checks that the keys of that JSON block are exactly `all@lyngon` plus `all`'s dependencies, so the template cannot drift when a plugin is added; `all`'s own list is already checked against the marketplace.
- Wording in the init `SKILL.md`, in `repo-files.md` and in this repository's `README.md`: `claude plugin install all@lyngon` stays the one install command; the committed settings enumerate.
- Leave `plugins/all/.claude-plugin/plugin.json` and the `dependencies` of `build` alone: declared dependencies are the repository's convention (CLAUDE.md, ADR 0008).
- Optional and owner-run: reproduce in a scratch repository with only `all@lyngon` at project scope and no user-scope installs; if it reproduces, report it to Claude Code with `/feedback`, quoting the message above.

## 2. `.gitignore` anchors the root directories

`tmp/` and `sandbox/` are unanchored in the `.gitignore` baseline of `repo-files.md` and in the init `SKILL.md` (near line 87).
`sandbox/` swallowed `infra/environments/sandbox/` in lyngon.com.

Change: `/tmp/` and `/sandbox/` in both places, and the same fix in this repository's own `.gitignore` as a separate commit.

## 3. The Terraform row becomes OpenTofu, with a tflint hook that works

Facts: in git-hooks.nix at the commit pinned in `devenv.lock`, the `tflint` hook has `entry = tflint`, `files = "\\.tf$"` and no `pass_filenames = false`, so prek passes file names, which tflint has rejected since 0.47 ("Command line arguments support was dropped in v0.47. You can use --chdir or --filter instead.").
The `terraform-format` and `terraform-validate` hooks there already run OpenTofu (`tools.opentofu`).
devenv 2.3 has `languages.opentofu` with `enable`, `package` and `lsp`.

Change, in `plugins/repo/skills/init/references/devenv.md`:

- Rename the row to OpenTofu: `opentofu.enable = true;`, formatter `terraform-format`, linter a custom `{name}-tflint` hook described in a new "### OpenTofu: tflint" subsection in the style of the basedpyright one: `pass_filenames = false`, `files = "\\.tf$"`, an entry that runs `tflint --recursive` from the infrastructure directory (or `--chdir` per root), the package `pkgs.tflint.withPlugins (p: [ p.tflint-ruleset-aws ])` so CI downloads nothing, and the `.tflint.hcl` the ruleset needs.
  Verify the nixpkgs attribute names against the pinned nixpkgs before writing them down.
- Keep the `.gitignore` column (`.terraform/`, `*.tfstate`, `*.tfstate.*`, `crash.log`, `*.tfvars`) and the note that `.terraform.lock.hcl` is committed.
- lyngon.com has a working wrapper in its `tmp/other-projects-devenv.nix`; ask me for it if you want to compare, since `tmp/` may already be gone.
- `plugins/repo/skills/add-package/references/workspaces.md`: the Terraform section says `languages.terraform.enable`; rename it to OpenTofu and `languages.opentofu.enable`.
- `plugins/repo/skills/add-package/references/package-files.md`: the `devenv.nix` template is Python-flavoured (ruff hooks).
  Say that the hooks come from the stack's row in `devenv.md`, and add an infrastructure environment example: format and tflint hooks scoped to the root's directory, no tasks.
  The foundation tier stays out; it is deferred in `docs/TODO.md`.

## 4. The `devenv test` line stops promising hook output

`repo-files.md` near line 85 and this repository's `CLAUDE.md` near line 18 say: "devenv detects coding agents and hides task output; run with `DEVENV_NO_AI_AGENT=1` to see it".
A passing `devenv test` prints task names and times only, in both modes (verified on devenv 2.3.1), so a session that wanted per-hook results was misled.

Change, in both places: `devenv test` prints task names and times; `DEVENV_NO_AI_AGENT=1` restores devenv's normal output; per-hook results come from `prek run --all-files` inside the devenv shell.
This matches what lyngon.com wrote into its own CLAUDE.md in commit c616ea6.

## 5. devenv 2.4.0

devenv 2.4.0 (released 2026-09-24, <https://github.com/cachix/devenv/releases/tag/v2.4.0>) says: "shell no longer runs test setup, including `devenv:git-hooks:run` and tasks with `before = [ "devenv:enterTest" ]`".
On 2.3.1, `devenv shell -- <cmd>` and every direnv re-evaluation ran the whole hook suite first: 3.9 s in this repository, 45 s in lyngon.com, paid by agents on every wrapped command.
The devkit's devenv module contributes nothing to it; it defines hooks, no tasks.

Precondition: `devenv version` on this machine reports 2.4.0 or later.
If it still reports 2.3.1, stop here, tell me to upgrade devenv from `nixos-configs` first, and leave this section for a follow-up; the bump would make `devenv` refuse to run in this repository.

Change: `require_version: ">=2.4.0"` in the `devenv.yaml` template and in this repository's `devenv.yaml`, the "Assumes devenv 2.3 or later" line in `devenv.md`, and a CHANGELOG line saying why.

## 6. The word "domain" is reserved

`shared/STRUCTURE.md` section 7 (symlinked into the `init` and `add-package` skills) reserves words with a universal sense.
Infrastructure repositories use "domain" for DNS names, and the structure uses it for the domain layer and the domain model of a Context.

Change: add "domain" to the reserved list: the domain layer and the domain model of a Context, never a DNS name; for DNS say "domain name", "zone" and "hostname".

## Out of scope

- The session hooks that export the devenv environment and warn about a branch behind its upstream: `docs/seed-prompts/session-environment-hooks.md`.
- An OpenTofu convention skill and the foundation tier: deferred in `docs/TODO.md`.
