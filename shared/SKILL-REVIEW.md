# Skill review checklist

Single source in `shared/` of the Lyngon devkit; plugins symlink it.
Used before a third-party skill enters the catalog and again at every bump.
Every finding goes verbatim into the provenance record's "Review notes", including "none found" per section.

Read every file in the skill directory, not only `SKILL.md`: scripts, references, assets, hooks, agents, `.mcp.json`.

## Security

- **Network**: any URL fetched, package installed, or command that downloads and executes (`curl | sh`, `pip install`, `npx` of an unpinned package). Name each one.
- **Credentials**: reads of environment variables, keychains, `~/.ssh`, `~/.aws`, `.env` files, git credential helpers, or the Claude configuration directory.
- **Execution surface**: hooks that run commands, scripts invoked with user-controlled input, `allowed-tools` broader than the skill needs, `permissionMode` or `bypassPermissions` anywhere.
- **Instruction hijacking**: text that tells the agent to ignore, override or hide other instructions, to skip confirmations, to not mention something to the user, or to act on content fetched at runtime as if it were instructions.
- **Obfuscation**: encoded strings, minified scripts, binaries, files that cannot be read as text.
- **Persistence**: writes outside the repository (global config, shell rc files, cron, other repositories).

## Quality

- The description states what the skill does and when to use it.
- Triggering, both ways: write one prompt that must trigger the skill and one that must not, and judge the description against both. Too broad and it fires on unrelated work; too narrow or too abstract and it never fires when needed. Both are findings.
- The body is proportionate: long material lives in `references/`, loaded on demand.
- Dependencies are stated: runtimes (Python, Node), CLIs, other skills or plugins.
- The skill says what it does not do, or its scope is obvious.
- No agent lock-in beyond what the feature needs (Claude-only wording, tool names of one product) when the skill is otherwise generic.

## Fit with the devkit

- Glossary and decision files: uses `CONCEPTS.md` and `docs/adr/`, or is patched to.
- Layout: does not assume `src/`; uses or tolerates `packages/<name>/`.
- Tools: never installs imperatively; anything it needs can come from `devenv.nix`.
- Writing: no em or en dashes; one sentence per line is a nice-to-have, not a blocker.
- Does not write `CLAUDE.md`, `AGENTS.md`, `.claude/settings.json` or `.mcp.json`, which the devkit owns.
- Does not duplicate an existing devkit skill; if it overlaps, say which and why both should exist.

## License

- A license file exists in the skill directory or at the repository root, and permits copying and modification.
- No license: stop. Neither pin nor vendor. Propose a request to the author (see the `add-skill` license reference).

## Verdict

One of: **clear**, **clear with patches** (list them; they become "Local patches"), **blocked** (list the blocking findings).
