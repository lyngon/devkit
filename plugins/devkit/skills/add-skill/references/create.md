# Creating a new in-house skill

Input: the design settled by `discover:approach` (name, concern, for development or for anywhere, does and does not, invocation mode, inputs and outputs, a must-trigger prompt and a must-not-trigger prompt).

## Engine

If the `skill-creator` plugin is installed (the Skill tool lists `skill-creator:skill-creator`), invoke it with the settled design as the brief and let it write the first draft.
It expects Python for its scripts; run them through `nix shell nixpkgs#python3 nixpkgs#python3Packages.pyyaml` if the devenv lacks Python, never by installing.
If it is not installed, write the skill from the house shape below.

Either way the result must satisfy the house shape before it is done.

## House shape

```text
plugins/<concern>/skills/<name>/
  SKILL.md              frontmatter on line 1; name equals the directory; description says what and when
  references/*.md       anything longer than a screen, linked by relative path
```

`SKILL.md` sections: a one-paragraph overview, "When to use", "When not to use", the workflow as numbered steps, and links to references.
`disable-model-invocation: true` for skills that write many files or ask many questions; model-invocable only when the trigger is unambiguous.
No dashes, one sentence per line.
What the skill says about the structure goes under a `With the Lyngon structure` heading, the one conditional heading, unless the plugin is `repo` or `devkit`; `validate-shipped-text` checks it.

## Evals

Create at least one case under `plugins/<concern>/evals/<case>/`: a `prompt.md` with the must-trigger prompt and one grader (`regex`, `tool_used`, `file_exists` or `llm`) that checks the skill's observable effect.
Score it as the skill's step "Finish the change" says.
Report the result faithfully; a failing eval is a finding, not a reason to delete the case.

## Bookkeeping

- Update the plugin's README.
- New concern plugin: same files as in `install.md`.
- A member of `all` declares no `dependencies`: its skills name the skills of other members as `<plugin>:<skill>`, and `validate-shipped-text` fails a name that no skill has.
- Run `devenv test`.
- Commit as one commit on the feature branch, `feat(<concern>): add <name> skill`.
