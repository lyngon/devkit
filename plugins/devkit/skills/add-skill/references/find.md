# Finding skills

Search in this order and stop when the target is unambiguous.
Record for each hit: repository URL, path, default-branch commit, license, frontmatter description, file count.

## From a URL or `owner/repo[/path]`

Fetch the repository with `git clone --depth 1 --filter=blob:none --sparse` into the scratchpad, then `git sparse-checkout set <path>`.
If the path is a plugin (has `.claude-plugin/plugin.json`), list its skills; if it is a skill directory (has `SKILL.md`), that is the target; if it is a repository root, look for both.

## From a name

1. **GitHub code search**, primary, needs `gh auth`:

   ```sh
   gh search code "name: <name>" --filename SKILL.md --limit 20 --json repository,path
   ```

   Also try the name without hyphens and with the author's handle as `user:<handle>`.
2. **Anthropic's repositories**: `anthropics/skills` and `anthropics/claude-plugins-official`, searched the same way with `repo:`.
3. **skills.sh** (Vercel): fetch `https://skills.sh` search pages by name; do not run the `npx skills` CLI, the devenv has no Node.
4. **agentskills.io** directory: `https://agentskills.io/skills`, fetch and search.

## From a description (Case B)

Run the GitHub search with three or four phrasings of the behaviour against `--filename SKILL.md`, and search the two Anthropic repositories and the two directories for the same phrasings.
Keep hits whose description covers at least the core of the behaviour; drop the rest with a one-line reason.

## Trust

A hit from an unknown author is not less eligible, but the review is what makes it eligible.
Never install from a hit whose repository cannot be cloned at a fixed commit.
