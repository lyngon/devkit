# Installing

Everything below is checked by `scripts/validate-marketplace.sh`; read it when unsure.

## Vendored skill

Target: `plugins/<concern>/skills/<name>/`.

1. Copy the upstream skill directory, minus files for other agents (`agents/openai.yaml` and similar) and minus anything the review blocked.
2. Copy the upstream license file to `LICENSE` in the skill directory (repository-level license if the skill has none of its own).
3. Rewrite to Lyngon vocabulary (`CONCEPTS.md`, `packages/<name>/`, no dashes, one sentence per line) and rename the skill if the settled name differs. Namespace any skill calls (`plugin:skill`).
4. Write `UPSTREAM.md` from `catalog/UPSTREAM-TEMPLATE.md`: upstream URL, path, name, version, 40-character commit, license, reviewer and date, why it is here, every local patch, the review findings.
5. Frontmatter `name` must equal the directory name; `description` must state what and when.

If the concern plugin is new: create `plugins/<concern>/.claude-plugin/plugin.json` (name, version `0.1.0`, description, author, license `Apache-2.0`, `dependencies` if it calls other plugins' skills), `CHANGELOG.md`, `README.md`, and add the marketplace entry without a `version` field.
If it exists: bump its minor version in `plugin.json`, add a changelog entry, update its README skill list.

## Pinned plugin

Target: a marketplace entry plus `catalog/<name>.md`.

1. Marketplace entry with `source` of kind `github` (`repo`), `url`, or `git-subdir` (`url` plus `path`), the 40-character `sha`, and a `version`: the upstream `plugin.json` version, or a calendar version such as `2026.9.16` when upstream declares none.
2. `catalog/<name>.md` from `catalog/TEMPLATE.md`, mentioning the same commit, listing every skill, agent, hook and script that was read, the reviewer, and the review findings.

## Always

- Enable the plugin in this repository's `.claude/settings.json` when the devkit itself should use it.
- Run `devenv test`.
- Do not commit. Offer `feat(<concern>): add <name> skill` or `feat(catalog): pin <name>`.
