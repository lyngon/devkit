# Principles and steering documents

The first of six pieces that replace the devkit's gated workflow with principles, steering documents and checks.
The pieces, their order and what is settled for each are in [the roadmap](2026-10-07-philosophy-overhaul-roadmap.md).
This file is transient and is removed by the change that finishes the piece.

## Design

### Goal

An agent in a Lyngon repository is steered by a small set of documents that state only what the code cannot show, and by named principles it applies with judgment.
The owner reads those documents and the pull request, and nothing else has to be approved before work starts unless the owner asks for a gate.

After this piece:

- Every Lyngon repository has one definition of a steering document, and a check for each of its rules that a tool can decide.
- A decision is recorded only when it passes the admission test, under its own name, and is deleted when it stops being true.
- Agents can read 32 named principles, 24 vendored from pstack and 8 written by Lyngon.
- Agents can ask why code is the way it is and get an answer from git, pull requests, decision records and issues.

The workflow itself does not change in this piece.
The review gates, plans and the nine superpowers skills stay until the workflow piece.

### Approach

The piece lands as two pull requests from this one design, in this order.

1. `feat/steering-documents`: the document rules, their checks, the templates that `repo:init` and `repo:add-package` write, and the devkit's own migration to them.
2. `feat/principles`: the `principles` plugin and the `why` skill, both vendored through `/devkit:add-skill`.

The rules land first because the principles cite them.
This file stays in `docs/plans/` on the default branch between the two pull requests, and the second removes it.

Existing text earns its way into the new shape, never the reverse.
Each line of the devkit's agent file and each of its 19 decision records is kept only if it passes the admission test.

### Components

#### The admission test

One sentence, used unchanged wherever a skill or document states it:

> Write it down only when a competent agent, seeing just the files it opened, would plausibly contradict it, wrongly, with nothing failing.
> When a check can fail instead, write the check.

It decides whether any text enters a steering document.
It replaces the three-part test for decision records (hard to reverse, surprising, a real trade-off).

#### Steering documents of a repository

| Path | Holds | Loaded |
| --- | --- | --- |
| `INTENT.md` | Product, audiences, done, failure, non-goals, priorities, horizon | Every session, through the agent file |
| `.claude/CLAUDE.md` | One line, `@../INTENT.md` | Every session |
| `.claude/rules/<name>.md` | One repository principle, or one rule that has no check yet | At launch without `paths:`, otherwise when a matching file is read or edited |
| `CONCEPTS.md` | Terms | On demand |
| `docs/decisions/<name>.md` | One decision record | On demand, and through `why` |

`README.md` is not a steering document.
No `AGENTS.md` exists anywhere, and no `CLAUDE.md` exists outside `.claude/`.
The organization's principles are not in any repository; they come from the `principles` plugin.

A file under `.claude/rules/` is named after its principle in kebab-case.
Its body is the statement in one or two sentences, then one sentence starting `Why:`.
It carries a `paths:` field whenever the principle concerns part of the tree.

`INTENT.md` gains one optional section, `## Priorities`, between `## Non-goals` and `## Horizon`.
Each line has the form "X over Y".
A line enters only after an owner answered a real question from an agent, so the section starts absent.
The 50-line limit stays.

#### Package documents

A package keeps a required `README.md`.
It gets an `INTENT.md` only when it has its own audience, its own done or failure, or its own non-goals that the root does not state.
That file uses the root's section names and holds only the sections that differ.
A package never has a `CLAUDE.md`; a principle that concerns one package is a file under `.claude/rules/` scoped to the package's path.

#### Decision records

- Directory `docs/decisions/`, and `libs/<ctx>/docs/decisions/` for a context.
- One file per decision, named `<slug>.md`, where the slug is the title in kebab-case. No number.
- The title is the decision as a sentence. The body is one to three sentences of context, decision and reason. `## Considered options` and `## Consequences` stay optional.
- The last line is `Enforced by: <name of the check>` or `Enforced by: judgment`.
- No `Status:` line and no `## Change log`.
- A record is edited freely while its file name stays true. When the decision changes, the file is deleted and a new one is written in the same change. When a check comes to carry the decision, the file is deleted.

The term is decision record.
"ADR" is avoided, because agents know it as numbered, carrying a status and never deleted.

#### The check: `validate-documents`

A new hook in the baseline module, `devenv/validate-documents.py`, enabled by `lyngon.enable` with every value a `mkDefault`.
Each message names the fix.
It looks at tracked files only and skips every `vendor/` and `generated/` directory.
A repository keeps a fixture tree out of it through the hook's `excludes`, as with any baseline hook.
It fails when:

1. A file named `AGENTS.md` exists anywhere.
2. A file named `CLAUDE.md` exists anywhere but at `.claude/CLAUDE.md` in the repository root.
3. A directory `docs/adr/` exists, at the root or in a package.
4. A file in a `docs/decisions/` directory has a name that is not kebab-case or that starts with digits and a hyphen, lacks a last line starting `Enforced by:`, has a line starting `Status:`, or has a heading `## Change log`.
5. An `INTENT.md` is longer than 50 lines, or has a `##` heading outside Product, For whom, Done means, Failure means, Non-goals, Priorities, Horizon.
6. A file under `.claude/rules/` has a name that is not kebab-case, or is longer than 100 lines.

`validate-structure` changes with it: `PACKAGE_DOCS` becomes `README.md` alone, and its `AGENTS.md` check is removed.

#### The structure marker

The sentence "This repository follows the Lyngon structure" in the root agent file is no longer a marker.
`lyngon.structure.enable = true` in `devenv.nix` is the only one.
The `repo` plugin's session hook, `add-package`, `docs/conventions/prerequisites.md` and `validate-prerequisites` read that instead.

#### Skills, shared documents and templates that change

- `conventions:documents`: rewritten to the table and rules above. Its `paths:` cover `INTENT.md`, `CONCEPTS.md`, `README.md`, `.claude/CLAUDE.md` and `.claude/rules/*.md`.
- `conventions:adr` becomes `conventions:decision-record`, with `paths: ["**/docs/decisions/*.md"]`.
- `shared/ADR-FORMAT.md` becomes `shared/DECISION-RECORD-FORMAT.md`, with both symlinks updated. A repository's override moves to `docs/conventions/decision-record.md`.
- `discover:domain-model`: offers a decision record by the admission test, and its file trees show `docs/decisions/`. Recorded as a local patch in its `UPSTREAM.md`.
- `shared/STRUCTURE.md`: the layout tree, section 3.3, section 4.3 and item 4 of section 4.4.
- `repo:init`: writes `.claude/CLAUDE.md` with the one import line, no root `CLAUDE.md`, no `AGENTS.md`, and the `INTENT.md` template without a Priorities section.
- `repo:add-package`: writes `README.md`, asks once whether the package has its own audience or non-goals, and writes `INTENT.md` only on a yes.
- The `conventions` session hook: its last line becomes "Terms are in CONCEPTS.md, decisions in docs/decisions/, this repository's principles in .claude/rules/."
- Every other mention of `docs/adr`, of a record by number, or of `AGENTS.md` in the plugins, `shared/`, `scripts/`, `devenv/` and the root documents (34 numbered references in 19 files today).
- `docs/conventions/prerequisites.md` and `validate-prerequisites`: the `documents` terms become `CONCEPTS.md`, `docs/decisions`, `INTENT.md`, `CLAUDE.md`, `.claude/rules`, `docs/TODO.md`, `docs/conventions`.

#### What the devkit assumes

Three assumptions, each stated as a non-goal in `INTENT.md`:

- "Supporting agents other than Claude Code, until a second agent is in use at Lyngon." becomes "Supporting any agent harness other than Claude Code. A second harness would be a port."
- Added: "Supporting macOS or Windows. Lyngon machines run Linux."
- Added: "Supporting a development repository without Nix and devenv."

A plugin for development may assume Nix and devenv.
A plugin that is not for development, such as `writing`, assumes neither.
This piece states the assumptions and nothing more; shrinking the prerequisite system to match goes with the workflow piece.

What follows from the first assumption:

- The rule "Skill bodies stay agent-neutral" is removed from the devkit's agent file.
- The bullet "No agent lock-in beyond what the feature needs" is removed from `shared/SKILL-REVIEW.md`.
- The item on an agent-agnostic marketplace is removed from `docs/TODO.md`.

#### The devkit's own migration

The root `CLAUDE.md` is replaced by `.claude/CLAUDE.md` holding the import line, and the `AGENTS.md` symlink is deleted.
Its lines are sorted by the admission test into three groups.

Lines that a check already carries are dropped: the plugin file set, the `sha` and catalog rule, `UPSTREAM.md`, the `all` and `core` bundles, prerequisites, the generated plugin table.
Lines that the tree shows are dropped: the layout descriptions.
Lines that hold for every Lyngon repository are dropped: the Documents section.

The rest become files under `.claude/rules/`, all scoped by path:

| File | Scope | Statement |
| --- | --- | --- |
| `shipped-text-never-assumes-this-repository` | `plugins/**`, `shared/**`, `devenv/**` | What the devkit ships is written for any Lyngon repository; rules for developing the devkit live only here. |
| `one-plugin-per-concern` | `plugins/**`, `.claude-plugin/**` | A plugin is named after one concern and holds its skills, in-house and vendored side by side. |
| `share-by-symlink-and-dependency` | `plugins/**`, `shared/**` | Plugins share documents through symlinks into `shared/` and behaviour through `dependencies`; never copy, never edit through a symlink. |
| `baseline-values-are-defaults` | `devenv/**` | Every value the baseline sets is a `mkDefault`. |
| `every-plugin-change-is-versioned` | `plugins/**` | A user-visible change to a plugin bumps its version and adds a changelog entry in the same commit. |
| `third-party-skills-enter-through-add-skill` | `plugins/**`, `catalog/**` | Third-party text enters only through `/devkit:add-skill`, and every local change is listed under "Local patches". |
| `readme-tree-mirrors-the-init-file-set` | `README.md`, `plugins/repo/skills/init/**` | The example tree in `README.md` shows exactly the files `repo:init` writes. |
| `long-skill-content-goes-to-references` | `plugins/**/SKILL.md` | What every invocation needs stays in `SKILL.md`; the rest goes to `references/`. |
| `sandbox-is-the-owners` | `sandbox/**` | Write there only when asked. |
| `work-in-progress-files` | `docs/TODO.md`, `docs/seed-prompts/**`, `docs/plans/**` | The current rules for deferred work, seed prompts and plan files, until the workflow and issue-pipeline pieces replace them. |

`readme-tree-mirrors-the-init-file-set` is a rule a tool could decide, so it is debt for the rules-as-checks piece.

The 19 records move to `docs/decisions/` as follows.

| Record | Verdict | Carried by |
| --- | --- | --- |
| 0001 one plugin per concern | Delete | `.claude/rules/one-plugin-per-concern.md` |
| 0002 mixed vendoring policy | Delete | Superseded since 0006 |
| 0003 devenv generates `.mcp.json` | Keep as `devenv-generates-mcp-json-claude-settings-is-committed-by-hand` | Judgment |
| 0004 `AGENTS.md` is a symlink | Delete | `validate-documents` |
| 0005 `INTENT.md` without stories | Delete | `validate-documents`, check 5 |
| 0006 pin per plugin, vendor per skill | Delete | `validate-marketplace` and `one-plugin-per-concern` |
| 0007 vendored skills are rewritten | Keep as `vendored-skills-are-rewritten-not-merged`, trimmed to what still holds | Judgment |
| 0008 shared documents and dependencies | Delete | `validate-marketplace` and `share-by-symlink-and-dependency` |
| 0009 the devenv module lives here | Delete | The tree, and `baseline-values-are-defaults` |
| 0010 no license, no catalog entry | Keep as `no-license-no-catalog-entry` | `validate-marketplace` and judgment |
| 0011 the `all` bundle | Delete | `validate-marketplace` |
| 0012 kind-first layout | Delete | `shared/STRUCTURE.md`, which states it with its reasons |
| 0013 one workspace per language | Delete | `shared/STRUCTURE.md` |
| 0014 plugins declare prerequisites | Delete | `validate-prerequisites` and `docs/conventions/prerequisites.md` |
| 0015 baseline is the prerequisite | Delete | The same |
| 0016 two review gates | Keep as `planned-work-is-reviewed-at-two-gates` until the workflow piece | Judgment |
| 0017 the workflow is a prerequisite | Delete | `validate-prerequisites` and `validate-marketplace` |
| 0018 owner gates | Keep as `owner-gates-are-declared-in-the-plan-and-pre-approved-by-name` until the workflow piece | Judgment |
| 0019 plans carry decisions and facts | Keep as `plans-carry-decisions-and-facts-the-implementer-writes-the-tests-and-the-code` until the workflow piece | Judgment |

0007 loses its first consequence (byte-identical copies, undone by 0008) and its mention of `packages/`, and keeps the other two.
0010 stays although a check exists, because an agent could satisfy the check by writing a license file the upstream never published.
Before 0011 is deleted, `validate-marketplace` must fail with the reason when the `all` plugin is missing; if it does not, that check is added.

`CONCEPTS.md` loses its three uses of "convention documents", which become "shared documents".

#### The `principles` plugin

- Plugin `principles`, version 0.1.0, declaring `Prerequisites: documents`, so it joins `core` and `all`.
- One skill, `principles:index`. Its `SKILL.md` is the index, one line per principle in the form `- **<name>** (<origin>). <When it applies>. <The rule in one sentence>.`, where the origin is pstack or Lyngon.
- One file per principle, `references/<name>.md`, each under 100 lines.
- One provenance record and one license for the 24 vendored files. Upstream `https://github.com/cursor/plugins`, path `pstack/skills/principle-*`, commit `9f451cf875ad1239912762f67741e8e5ba6ac0f1`, MIT.
- Vendored names drop the `principle-` prefix.
- The index keeps upstream's groups (core, architecture, verification, delegation, meta) and adds one, steering, for the Lyngon principles.

Local patches to the vendored files:

- All: frontmatter removed, links between principles repointed to sibling files, one sentence per line, "the human" replaced by owner or operator.
- `never-block-on-the-human`: its boundaries become the gate and the list below.
- `encode-lessons-in-structure`: the "brain note" route is removed. A first occurrence is noted in the pull request, a repeat gets the strongest check that works, and a repeat no tool can decide becomes a principle. It gains the sentence "A rule without a check is debt."
- `outcome-oriented-execution`: breakage stays inside a branch; the default branch and every pull request head pass the full check.
- `sequence-verifiable-units`: the change is the unit that lands; inside it, commits may tell the story.
- `explain-the-number` and `prove-it-works`: the sentences pointing at `benchmark-checklist` and `show-me-your-work` are left out until the workflow piece brings those skills.

`never-block-on-the-human` will state the gate as follows.
Ask only before an irreversible action, or for a product or preference call that no run can settle.
Product direction is the owner's.
Always ask before a merge, a push to the default branch, a force-push, a tag, a release, a publish, a deploy, deleting data or a remote branch, any message outside GitHub, and spending money.

The eight Lyngon principles, each written in upstream's shape (statement, why, pattern, test):

| Name | Statement |
| --- | --- |
| `record-what-the-code-cannot-show` | Prose enters the tree only through the admission test, and a decision that passes it is recorded in the same change. |
| `the-tree-is-current` | The tree holds what is true now. Superseded text is deleted, and git and `why` hold the past. |
| `review-results-not-plans` | The owner steers through steering documents and reviews results. Nothing waits for approval by default. A gate on requirements, a specification, a plan or tasks exists if and only if the owner asked for it explicitly, and then the agent stops there. |
| `fix-debt-in-its-own-change` | Debt found is fixed in the same session in its own change when the fix can be proven, and otherwise becomes an issue with the evidence. |
| `reshape-instead-of-commenting` | A comment explaining a surprise in your own code is fixed in the code. |
| `name-things` | Give everything a name and refer to it by that name. An ordered item also carries a three-digit prefix, as in `001-steering-documents`, so that it sorts in order. Keep a bare number only where a tool assigns it. |
| `prescribe-proof-not-steps` | Anything written for an agent to follow states what must hold and what proof is owed, and gives steps only where they are facts the reader cannot derive. |
| `use-purpose-built-tools` | A script or check uses the tool built for the task, such as jq for JSON, declared through Nix and pinned, and takes nothing from the ambient PATH. Highly custom logic is a Python program shipped as source next to what uses it. |

`review-results-not-plans` describes where the devkit is heading.
Until the workflow piece lands, the gated skills still ask for approval, and the principle's file says so in one sentence that the workflow piece removes.

The `conventions` session hook gains one line: "principles:index before work that takes judgment; then read the file of each principle that applies."

`validate-marketplace` gains one check: the index and `references/` list the same names, and no file exceeds 100 lines.

#### The `why` skill

- `discover:why`, user-invocable, vendored from `pstack/skills/why` at the same commit.
- Kept files: `SKILL.md`, `references/epistemics.md`, `references/investigator-prompt.md`, `references/synthesizer-prompt.md`, `references/source-playbook.md`, `references/sources/code-archaeology.md`, `references/sources/incident-postmortem.md`.
- Left out: the playbooks for Slack, Notion, Datadog, Sentry, Databricks and Linear.
- Added: `references/sources/github-issues.md`, written by Lyngon and listed as a local patch.

Local patches:

- The seven evidence categories stay as a list, so a later source has a place. Two have playbooks.
- With only source control and the issue tracker available, the agent runs one pass itself, with no investigators and no synthesizer.
- The code playbook reads `docs/decisions/` first, then blame, log and pull request bodies through `gh`.
- Cursor's task parameters and the model role lines are removed; a subagent inherits the session's model.
- The output keeps upstream's sections and its split between found, inferred and unknown.

### Data flow

At session start Claude Code loads `.claude/CLAUDE.md`, which imports `INTENT.md`, and every file under `.claude/rules/` that has no `paths:` field.
The `conventions` session hook adds the pointers to `CONCEPTS.md`, `docs/decisions/`, `.claude/rules/` and `principles:index`.

When the agent reads or edits a file, Claude Code loads the rule files whose `paths:` match it.
When work takes judgment, the agent reads the index and then the files of the principles that apply.
When it needs a reason, `why` reads the decision records, then git and the forge.

When a decision passes the admission test, the agent writes its record in the same change.
On commit, `validate-documents` and `validate-structure` fail on anything the rules above forbid.

### Error handling

- A repository that updates its devkit input before migrating fails `validate-documents` on its root `CLAUDE.md`, its `AGENTS.md` and its `docs/adr/`. Each message says where the content goes.
- A record without an `Enforced by:` line fails the commit, and so does a `Status:` line.
- A principle in the index without a file, or a file without an index line, fails `validate-marketplace`.
- `why` reports a source it could not reach as a gap in its output, and never as "nothing found".
- Whether a compaction re-reads `.claude/CLAUDE.md` and its import is not verified. The documentation says it re-reads the project agent file. If the import is lost, the agent loses the intent mid-session, so this is checked during implementation and reported in the pull request.

### Testing

- Fixture tests for `validate-documents`, one failing and one passing tree per check, in `devenv/tests/validate-documents.sh`, run by `devenv test`.
- The `validate-structure` fixtures change with `PACKAGE_DOCS`.
- The `repo` hook tests cover the new structure marker.
- A fixture for the new `validate-marketplace` check.
- One headless run in a scratch repository proves that `.claude/CLAUDE.md` with the import loads the intent, that an unscoped rule file loads at launch, and that a scoped one loads after a matching read. This passed on Claude Code 2.1.283 on 2026-10-07 and is repeated against the files `repo:init` writes.
- One headless run asks for a small change that takes judgment, and the transcript must show the index and at least one principle file being read.
- `why` is run once on "why is the `all` bundle the install unit?" after the records have moved, and its output goes in the pull request.
- `devenv test` passes on both branches.

### Out of scope

- Everything in the workflow piece: the mode, the playbooks, the other pstack skills, `correct` and the mistake ledger, the pull request sections, squash merging, the change as a unit, and question names in the interview skill.
- The later pieces: the agent identity, the issue pipeline, the GitHub setup that `repo:init` emits, and rules as checks, including the five structure checks.
- Deleting the three records about gates and plans, which goes with the workflow piece.
- Renaming the `conventions` plugin and `docs/conventions/`, which goes with the rules-as-checks piece.
- Shrinking the prerequisite system now that every development repository is assumed to have Nix and devenv, which goes with the workflow piece.
- Migrating `lyngon.com`. It keeps working until it updates its devkit input, and migrates in a change of its own.

### Decisions for the owner to check

Each of these is a choice made while writing the design, not one settled in the interview.

- `.claude/CLAUDE.md` holds only the import of `INTENT.md`. The full-check command and the pointers come from the session hook and `conventions:engineering`, as they do today.
- The piece lands as two pull requests, and this file stays on the default branch between them.
- The wording of the three non-goals in `INTENT.md`.
- The name `use-purpose-built-tools` for the principle on tools.
- The skill names `principles:index`, `conventions:decision-record` and `discover:why`.
- A new baseline hook, `validate-documents`, with the six checks listed.
- The verdict on each of the 19 records, and the ten rule files that replace the devkit's agent file.
- `review-results-not-plans` ships before the workflow that honours it.
