# Installing

Everything below is checked by `scripts/validate-marketplace.sh` and `scripts/validate-shipped-text.py`; read them when unsure.

## Vendored skills

Target: `plugins/<concern>/skills/<name>/` for each path, and one record for their upstream, `catalog/vendored/<upstream>.md`.
`<upstream>` is a short name for the upstream in kebab-case (`pstack`, `superpowers`), the same in the name of the record and of the license.

1. Copy each upstream skill directory, minus files for other agents (`agents/openai.yaml` and similar) and minus anything the review blocked.
2. Copy the upstream license file to `shared/LICENSE-<upstream>` (repository-level license if the skill has none of its own), and link it under the same name into the root of every plugin that receives a path. No skill directory holds a license file.

   ```sh
   ln -s ../../shared/LICENSE-<upstream> plugins/<concern>/LICENSE-<upstream>
   ```

3. Rewrite to Lyngon vocabulary (`CONCEPTS.md`, the layout in `shared/STRUCTURE.md`, no dashes, one sentence per line) and rename the skill if the settled name differs. Namespace any skill calls (`<plugin>:<skill>`). Put what the skill says about the structure under a `With the Lyngon structure` heading, unless the plugin is `repo` or `devkit`.
4. Write `catalog/vendored/<upstream>.md` from `catalog/vendored/TEMPLATE.md`: upstream URL, 40-character commit, version, license, reviewer and date, then for each path why it is here, its row in the table of what was taken (upstream path and destination), every local patch and the review findings, each under its destination. When the upstream already has a record, add the paths to it and leave its commit as it is.
5. Frontmatter `name` must equal the directory name; `description` must state what and when.

If the concern plugin is new: create `plugins/<concern>/.claude-plugin/plugin.json` (name, description, author, license `Apache-2.0`, `dependencies` if it calls other plugins' skills, and no `version`) and `README.md`, and add the marketplace entry, also without a `version`, because the commit is the plugin's version. Add it to the `dependencies` of `plugins/all/`; the validator refuses the marketplace otherwise.
If it exists: update its README skill list.
Either way, the plugin's README names the upstream, the license link and the record.

## Pinned plugin

Target: a marketplace entry plus `catalog/<name>.md`.

1. Marketplace entry with `source` of kind `github` (`repo`), `url`, or `git-subdir` (`url` plus `path`), the 40-character `sha`, and a `version`: the upstream `plugin.json` version, or a calendar version such as `2026.9.16` when upstream declares none.
2. `catalog/<name>.md` from `catalog/TEMPLATE.md`, mentioning the same commit, listing every skill, agent, hook and script that was read, the reviewer, and the review findings.

## Always

- Enable the plugin in this repository's `.claude/settings.json` when the devkit itself should use it.
- Run `devenv test`.
- Commit as one commit on the feature branch, `feat(<concern>): add <name> skill` or `feat(catalog): pin <name>`; do not push, since the push comes when the whole piece of work is done. Several paths of one upstream are one commit that names each skill, without a scope when more than one plugin receives a path.
