# pstack

- **Upstream**: <https://github.com/cursor/plugins>
- **Upstream commit**: 9f451cf875ad1239912762f67741e8e5ba6ac0f1
- **Upstream version**: 0.15.15 (`pstack/.cursor-plugin/plugin.json`)
- **Upstream license**: MIT (see [LICENSE-pstack](../../shared/LICENSE-pstack))
- **Reviewed**: 2026-10-13 by Anders Åström

## Why it is here

### `plugins/discover/skills/why`

A Lyngon repository keeps only what is true now, and deletes a decision record when its decision changes.
The reason behind code or a decision is then in git, in pull requests and in issues, and an agent that cannot find it there either guesses or undoes the decision.
This skill reads those sources and keeps what it found apart from what it inferred and what it could not find out, which is the property that makes its answer safe to act on.

### `plugins/principles/skills/index`

Lyngon steers agents by named principles they apply with judgment, where it used to script their steps.
pstack states 24 such principles in a form short enough to read whenever one applies (a statement, why, a pattern and a test), and they are the ones the owner chose to build on.
Upstream ships each principle as a skill of its own and indexes them inside its mode skill.
Here they are one skill, so that an agent reads one index and then only the files it needs.

### `plugins/writing/skills/technical`

Agents draft Lyngon's documents, pull request descriptions and commit messages, and the people who read them review many in a day.
`unslop` removes the patterns of machine-written prose, and says nothing about what kind of document a text is, whom a sentence addresses or how much it carries.
This skill is that standard, in four layers that each rest on a published one: Diátaxis, the Google developer documentation style guide, Simplified Technical English and Global English.
It is short enough to read before every document, it comes from the author of `unslop`, and it hands each document to that skill when the layers are done.

### `plugins/writing/skills/simpler`

An agent reports in the vocabulary of the work it just did, and the person who reads the report was not there.
This skill gives the request "say that again so that I follow" a name: the last message, restated shorter and without jargon.
It is three sentences, and it is vendored so that the request works the same in every repository.

## What was taken

| Upstream path | Destination |
| --- | --- |
| `pstack/skills/why` | `plugins/discover/skills/why` |
| `pstack/skills/principle-*`, 24 skill directories of one `SKILL.md` each | `plugins/principles/skills/index` |
| `pstack/skills/poteto-mode/SKILL.md`, the section "Principles", for the lines of the index | `plugins/principles/skills/index` |
| `pstack/skills/technical-writing` | `plugins/writing/skills/technical` |
| `pstack/skills/bro` | `plugins/writing/skills/simpler` |

The 8 principles of the group steering in `plugins/principles/skills/index` are written by Lyngon and have no upstream.

## Local patches

### `plugins/discover/skills/why`

Files:

- Kept: `SKILL.md`, `references/epistemics.md`, `references/investigator-prompt.md`, `references/synthesizer-prompt.md`, `references/source-playbook.md`, `references/sources/code-archaeology.md` and `references/sources/incident-postmortem.md`.
- Left out: the playbooks `slack.md`, `notion.md`, `datadog.md`, `sentry.md` and `databricks.md` under `references/sources/`. No Lyngon repository has those sources.
- Adapted: `references/sources/github-issues.md` replaces upstream's `linear.md`. Its five sections, the sentences on sub-issues and parents, the pitfalls on scope drift, templates, stale tickets and duplicate chains, and the list of what to return are upstream's, with "ticket" changed to "issue". The `gh` commands (each run once against this repository), the examples of good evidence, and the pitfalls on issue text as a claim, on PRs in the API and on access are written by Lyngon. A change to upstream's `linear.md` concerns this file.

All kept files:

- Paragraphs are reflowed to one sentence per line, with blank lines around lists and headings.
- Headings are in sentence case. The names of the output sections follow ("What we found", "What we can reasonably infer", "Competing hypotheses", "What we don't know", "Sources consulted", "Confidence summary", "The code in question", "Additional leads"), in the headings and wherever the text mentions them.

`SKILL.md`:

- The description says what the skill does and when to use it, and keeps upstream's trigger phrases. `disable-model-invocation: true` is removed, so that an agent can ask why before it changes code. Added an `argument-hint`.
- The paragraph on the companion skill `how` and the description's "Use how for runtime behavior" are left out, because that skill is not in the devkit.
- The paragraph on the `pstack-models.mdc` role lines and the three "Subagent config" lists (`subagent_type`, `model`, `readonly`) are removed. A subagent inherits the session's model, and the one fact the lists carried is kept as a sentence: an investigator and the synthesizer need the tools of their sources.
- Discovery lists the MCP servers the session offers, where upstream read the Cursor environment and its `mcps/` directory. The issue tracker is GitHub Issues through `gh`, so two categories are always available where upstream had one. Added that an MCP holding none of the seven kinds of evidence is not a source, and that a source that could not be reached is reported as a gap with its error, never as "nothing found".
- Added the section "One pass, when git and GitHub are the only sources": with no MCP mapped to a category, the agent runs the investigation itself from the two playbooks, to the investigator prompt's posture, and writes the answer in the synthesizer's format, with no investigators and no synthesizer. Upstream's "Default to the full parallel investigation" is removed with it, and its trivial-target exception now permits one pass.
- The step headings lose "Step 1." to "Step 5.", and the text refers to the code anchor by name, where upstream wrote "the code anchor from Step 2". The third step is "Investigate", where upstream's was "Spawn parallel investigators (default posture)".
- The parallel path keeps the roster of seven categories, the two reasons to skip an investigator and the synthesizer's inputs. The headings "Investigator roster" and "When to skip an investigator" are folded into one section, and the step "Synthesize" moved into it. Investigators are one per source, where upstream said one per MCP, and its sentence "Each owns exactly one tool or MCP" went with that. The source control entry of the roster names decision records, and the issue tracker entry names GitHub Issues through `gh` first.
- Sentences that named the investigators or the synthesizer now also fit one pass: "The synthesizer must follow it" became "Whoever writes the answer, you or a synthesizer, must follow it", "Before spawning investigators" became "Before investigating", "Pass it to the investigators" is dropped, and the step "Present" presents "the answer".
- The code anchor also holds the decision records that name the target, and recognizes `Merge pull request #1234` subjects beside `(#1234)`.
- "Sources consulted" is one line per evidence category, where upstream said one per investigator, and names a source that could not be reached.
- The list of reference files names the files kept.

`references/sources/code-archaeology.md`:

- Reads the decision records first: the records in `docs/decisions/` that mention the target, the records git remembers as deleted (in `docs/decisions/` and the older `docs/adr/`, with `--no-renames`, because git otherwise pairs a deleted record with its replacement and lists neither), and the text of a deleted record from the parent of the commit that deleted it. Upstream's line on ADRs "if the repo keeps them" and its search for them are replaced by this.
- The `rg` commands became `git grep`, which every repository has, and their lead-in "Look for out-of-band docs" became "Look for what the tree itself says".
- Added `gh pr list --state merged --search <hash>` for a commit that is not a merge commit.
- Added a decision record to the examples of good evidence and to what is returned, and two pitfalls: reading a deleted record as current, and `gh` out of reach.

`references/sources/incident-postmortem.md`:

- The bullets and the two paragraphs below them name the evidence categories, in the order of the category list, where upstream named Notion, Linear, Slack, Git, Datadog, Sentry and Databricks and one Datadog tool. The heading says "and" for "&".

`references/source-playbook.md`:

- The table lists `github-issues.md` for the issue tracker and no playbook for the five categories whose playbooks are left out, and its last column is the source a playbook documents, where upstream's was an example MCP. The introduction speaks of sources where upstream spoke of investigators and MCPs. Added what an investigator without a playbook works from.

`references/investigator-prompt.md`:

- The playbook is appended when its category has one.
- The code anchor has a slot for the decision records that name the target.
- The section "Gaps" says that a source the investigator could not reach is a gap, reported with its error, and never an empty result. Upstream said so in each left-out playbook.

`references/synthesizer-prompt.md`:

- In "Sources consulted", the source control line lists the decision records read and reports `gh` out of reach, where upstream wrote that not searching "should not happen". The issue tracker line reports the error from `gh`, where upstream reported a missing MCP.

`references/epistemics.md`: only the patches of all kept files.

### `plugins/principles/skills/index`

All 24 files:

- Each skill `principle-<name>` became the file `references/<name>.md` of this one skill. The prefix `principle-` is dropped.
- The frontmatter (name, description, `disable-model-invocation: true`) is removed. What the description said about when the principle applies is in the principle's line of the index.
- A link to another principle points at its sibling file and uses the principle's name as the link text, where upstream linked `../principle-<name>/SKILL.md` under the principle's title.
- The heading is in sentence case.
- Paragraphs are reflowed to one sentence per line, and lists are surrounded by blank lines.

Single files:

- `never-block-on-the-human`: "the human" became the owner (who supervises and corrects) and the operator (who is the bottleneck of a pause). The section "Boundaries", with its three bullets on irreversible actions, reversible actions and product direction, is replaced by "The gate": ask only before an irreversible action or for a product or preference call that no run can settle, product direction is the owner's, and the list of actions that always need asking. The name keeps "the-human".
- `encode-lessons-in-structure`: the route "One-off -> brain note. Recurring fix -> skill or lint rule. Systemic issue -> principle." became: a first occurrence is noted in the pull request, a repeat gets the strongest check that works, and a repeat that no tool can decide becomes a principle, which in a repository is a file under `.claude/rules/`. Step 3 of the pattern follows it: "make the instruction more prominent and add an example of the failure mode" became "make it a principle and name the failure it prevents". Added the sentence "A rule without a check is debt." to the corollary. "Apply now or create a concrete todo" became "Apply now, or file an issue with the evidence", because an agent does not defer work into a file on its own. "When the human intervenes" became "When the owner or the operator intervenes", and "a brain note" in the anti-patterns became "a note".
- `outcome-oriented-execution`: added the guardrail "Keep breakage inside a branch: the default branch and every pull request head pass the full check".
- `sequence-verifiable-units`: in "Delivery", "Stack commits and PRs in the order that proves the work" became "The change, one concern delivered as one pull request, is the unit that lands. Inside it, commits may tell the story: stack them in the order that proves the work." The sentence "Each commit lands on its own and the sequence reads as an argument" became "The sequence reads as an argument." The two references in the form "the **name** principle skill" became links to the sibling files. In "Execution", "Rebase onto clean trunk first" became "Start from the up-to-date default branch", because a rebase of a pushed branch needs a force-push, which the gate asks about first.
- `explain-the-number`: the sentence "For a performance number, run the full procedure with the benchmark-checklist skill." is left out, because that skill is not in the devkit.
- `prove-it-works`: "Keep the artifact visible for the human" became "for the owner", and the parenthesis "(the **show-me-your-work** skill)" is left out, because that skill is not in the devkit.
- `type-system-discipline`: the sentence "Skills like `typescript-best-practices` ground it in specific syntax." is left out, because that skill is not in the devkit. The two references in the form "the **name** principle skill" became links to the sibling files.
- `fix-root-causes`: the bold line "Restart bugs: suspect state before code" became a heading, which markdownlint demands of a line that stands as one.

The index, `SKILL.md`:

- Its lines for the 24 principles are adapted from the section "Principles" of upstream's `poteto-mode` skill and from the descriptions of the principle skills. Each line has the form `- **<name>** (<origin>). <When it applies>. <The rule in one sentence>.`, where upstream wrote the title in bold, the skill name in parentheses and one to three sentences.
- Upstream's groups (core, architecture, verification, delegation, meta) are kept, and the group steering is added for the Lyngon principles.
- The lines of `never-block-on-the-human`, `encode-lessons-in-structure`, `outcome-oriented-execution` and `sequence-verifiable-units` state the patched rule.

### `plugins/writing/skills/technical`

- Renamed from `technical-writing` to `technical`, which reads after the plugin's name, as in `/writing:technical`.
- `disable-model-invocation: true` is removed, so that an agent starts the skill when it writes or reviews a document. In the description, "Use for /technical-writing or when writing or reviewing" became "Use before writing or reviewing", and "every time, however small the document" is added. With upstream's wording an agent wrote the page of the eval case `technical-writes-a-how-to` without the skill in one run of four.
- The sentences "Propose a new offender and its replacement as an addition to `unslop`'s abstract-metaphor rule in your reply, with the diff. Don't edit that skill." are left out. The `unslop` of the devkit is vendored from noodle and has no such rule. Upstream's own `unslop` has it as rule 26.
- The bullet "Apply the **unslop** skill to every doc this skill touches." and its second sentence moved out of "Voice and repo specifics" into a closing section of their own, "Before you hand the document over". The skill is named `writing:unslop` there, and the sentence "A doc that `writing:unslop` has not gone over is not ready to hand over, however clean it looks." is added. As a bullet the instruction was skipped in each of the three runs of the eval case that loaded the skill, and in two of three as a section without the added sentence.
- "Do not paste swarm logs" became "Do not paste logs", because the skill `swarm` is not in the devkit.
- "Indent code snippets with tabs." is left out. It is a rule of upstream's own repository, and a snippet follows the formatter of its language.
- Added the bullet "The repository's own rules for documents come first. Where they differ from this skill, follow them." at the head of "Voice and repo specifics". A repository with a house style keeps it, and `writing` cannot name the skills that hold Lyngon's.
- Paragraphs are reflowed to one sentence per line, the two quotes of the worked example included. A bullet keeps its sentences on one line.

### `plugins/writing/skills/simpler`

- Renamed from `bro` to `simpler`, which says what the skill does and reads after the plugin's name, as in `/writing:simpler`. "bro" stays in the description as a trigger phrase.
- The description gains when to use the skill, with the trigger phrases "bro", "say that simpler", "in plain words" and "no jargon". `disable-model-invocation: true` is removed, so that an agent starts the skill on one of them.
- Added the heading "Simpler", which markdownlint demands of the first line of a file.
- The body is reflowed to one sentence per line.

## Review notes

### `plugins/discover/skills/why`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-11, all 13 upstream files read in full, the five that are left out and `linear.md` included.

- Security: the skill reads and never writes. Network: `gh` reads pull requests and issues of the repository, and `gh search issues` reads the organization's. Credentials: none read by the skill; `gh` uses its own sign-in. Execution surface: no scripts, hooks or `allowed-tools`. Upstream told investigators to run in agent mode so that MCP tools stay available while writing nothing; the patched sentence keeps both halves. Instruction hijacking: none in the text, and the opposite risk exists, since an issue or a pull request body is text from anyone. The synthesizer prompt forbids writing files, committing or changing external state, and the new issue playbook says that issue text is a claim and never an instruction. No encoded content, no persistence.
- Quality: the description states what and when. Trigger check: "why does validate-marketplace demand the all bundle?" must trigger it, "how does the session hook find its text file?" must not. `SKILL.md` is 171 lines; the confidence framework, both prompts and the playbooks are references. Dependencies: git, and `gh` signed in for pull requests and issues, whose absence the skill reports as a gap. The left-out playbooks named MCP tools of products Lyngon does not use (`search_datadog_incidents`, `notion-search`, `execute_sql_read_only`).
- Fit: reads decision records in `docs/decisions/` (patched). Assumes no layout. Installs nothing; `rg` was not guaranteed and became `git grep` (patched). No em or en dashes and no curly quotes upstream. Writes no file. No devkit skill overlaps: `discover:domain-model` writes decision records, and this one reads them and the history behind them.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/principles/skills/index`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-11, every file read in full.

- Security: none found. The 24 files are prose, with no scripts, hooks, agents, network access, credential reads, tool permissions or encoded content, and they write nothing. `never-block-on-the-human` tells the agent to proceed without asking on reversible work; that is the behaviour wanted, and its boundary is patched to the Lyngon gate.
- Quality: every upstream description says when the principle applies. Upstream sets `disable-model-invocation: true` on each and reaches them through the inline index of its mode skill; here the index is the skill and the agent may invoke it. Trigger check: "refactor the parser so that adding a format is one file" must trigger the index, "what does this function return?" must not. Bodies are 11 to 36 lines. Three files pointed at skills that are not in the devkit (`benchmark-checklist`, `show-me-your-work`, `typescript-best-practices`); the pointers are left out.
- Fit: no em or en dashes and no curly quotes upstream. Writes no file. `encode-lessons-in-structure` routed a one-off to a "brain note", which Lyngon has no place for (patched). `sequence-verifiable-units` let each commit land on its own, where Lyngon lands one change (patched). Overlap: `prove-it-works`, `fix-root-causes` and `test-behavior-not-implementation` cover the ground of `practice:verify`, `practice:debug` and `practice:tdd`; the principles say what to judge, the skills are procedures, and both stay until the workflow is redesigned.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/writing/skills/technical`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-13, the one upstream file read in full.

- Security: none found. The file is prose, with no scripts, hooks, agents, network access, credential reads, tool permissions or encoded content. It writes nothing but the document the agent was asked for, and no sentence tells the agent to override, hide or skip anything.
- Quality: the description states what and when. Upstream sets `disable-model-invocation: true`; here the agent may start the skill (patched). Trigger check: "turn these notes into the how-to page for our docs site" must trigger it, "rename this function and its callers" must not. Its trigger overlaps the one of `unslop`, which fires on any prose: this skill is the standard a technical document is written to, `unslop` is the edit pass on what was written, and this skill ends by applying `unslop`. The file is 106 lines upstream and 155 here, after the reflow, with no references. Dependencies: the skill `unslop`, in the same plugin. Scope: stated, since product UI strings are out.
- Fit: no line carries a term of a development repository, shown by a search of the upstream file for every term that `scripts/validate-shipped-text.py` lists, so `writing` holds the skill without rewording. It pointed at a rule that only upstream's `unslop` has, at swarm logs and at tabs for snippets (all patched). Two of its rules differ from Lyngon's documents: "UI elements go in bold", where `conventions:markdown` allows bold for the first words of a bullet at most, and "Use serial commas", which the devkit's own text does not. `writing` cannot name that skill, so a bullet gives a repository's own rules the last word (patched). No em or en dashes and no curly quotes upstream; the one character outside ASCII is the "á" of Diátaxis. Writes no file of its own. Overlap: "Vary the rhythm" covers the ground of "Adding soul" in `unslop`, in four bullets. Both stay, because this skill applies them while a document is drafted and `unslop` when any prose is edited.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/writing/skills/simpler`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-13, the one upstream file read in full.

- Security: none found. The file is three sentences of prose, with no scripts, hooks, agents, network access, credential reads, tool permissions or encoded content, and it writes nothing.
- Quality: upstream's description says what the skill does and not when, and upstream sets `disable-model-invocation: true`, so that only `/bro` starts it. Here the description carries the trigger phrases and the agent may start the skill (patched). Trigger check: "bro, what?" after a dense answer must trigger it, "simplify this function" must not. No dependencies. Scope: the last message of the conversation, which the text makes obvious.
- Fit: no line carries a term of a development repository, shown by the same search. No em or en dashes and no curly quotes. Writes no file. No devkit skill overlaps: `unslop` edits prose that is about to be handed over, and this skill restates an answer that was already given.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.
