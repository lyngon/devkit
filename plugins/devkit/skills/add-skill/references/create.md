# Creating a new in-house skill

Input: the design settled by `discover:approach` (name, concern, prerequisites, does and does not, invocation mode, inputs and outputs, a must-trigger prompt and a must-not-trigger prompt).

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
Agent-neutral wording unless the feature is Claude-only.
No dashes, one sentence per line.
Every line about a prerequisite the plugin does not declare goes under a conditional heading (`With the Lyngon documents`, `With devenv`, `With the Lyngon structure`); `validate-prerequisites` checks it.

## Evals

Create at least one case under `plugins/<concern>/evals/<case>/`: a `prompt.md` with the must-trigger prompt and one grader (`regex`, `tool_used`, `file_exists` or `llm`) that checks the skill's observable effect.
Run once, cheaply:

```sh
claude plugin eval plugins/<concern> --case <case> --runs 1 --ablation none --no-publish
```

Report the result faithfully; a failing eval is a finding, not a reason to delete the case.
Evals are not wired into CI yet (token cost); note that in the changelog entry if it is the plugin's first eval.

## Bookkeeping

- Bump the plugin's minor version, add a changelog entry, update its README, including its `Prerequisites:` line when the skill raised it.
- New concern plugin: same files as in `install.md`, including the `Prerequisites:` line and the bundle memberships.
- If the skill calls skills from another plugin, add that plugin to `dependencies`.
- Run `devenv test`.
- Do not commit; offer `feat(<concern>): add <name> skill`.
