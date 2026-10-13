# pstack

- **Upstream**: <https://github.com/cursor/plugins>
- **Upstream commit**: 9f451cf875ad1239912762f67741e8e5ba6ac0f1
- **Upstream version**: 0.15.15 (`pstack/.cursor-plugin/plugin.json`)
- **Upstream license**: MIT (see [LICENSE-pstack](../../shared/LICENSE-pstack))
- **Reviewed**: 2026-10-11 by Anders Åström

## Why it is here

### `plugins/discover/skills/why`

A Lyngon repository keeps only what is true now, and deletes a decision record when its decision changes.
The reason behind code or a decision is then in git, in pull requests and in issues, and an agent that cannot find it there either guesses or undoes the decision.
This skill reads those sources and keeps what it found apart from what it inferred and what it could not find out, which is the property that makes its answer safe to act on.

### `plugins/discover/skills/how`

An agent that changes code it has not traced guesses at the flow around it, and a person who asks how a subsystem works gets an answer built from whichever files the agent happened to open.
This skill makes the reading a job of its own.
Subagents trace the code and one explanation comes back, with the flow, the files and the gotchas, and the session that asked keeps its context.
It is the companion `why` was written against, from the same author and in the same form, so each of the two hands a question over to the other by name.

### `plugins/discover/skills/explanation`

The owner reviews on the pull request, and so has to understand changes and subsystems that an agent wrote.
`how` and `why` each answer one question in the shape of a report.
This skill turns both into one account for a person: a plain definition first, the smallest complete answer, then more on request.
It keeps the hedges of `why`, so a reason is never taught as firmer than its evidence.

### `plugins/principles/skills/index`

Lyngon steers agents by named principles they apply with judgment, where it used to script their steps.
pstack states 24 such principles in a form short enough to read whenever one applies (a statement, why, a pattern and a test), and they are the ones the owner chose to build on.
Upstream ships each principle as a skill of its own and indexes them inside its mode skill.
Here they are one skill, so that an agent reads one index and then only the files it needs.

## What was taken

| Upstream path | Destination |
| --- | --- |
| `pstack/skills/why` | `plugins/discover/skills/why` |
| `pstack/skills/how` | `plugins/discover/skills/how` |
| `pstack/skills/teach` | `plugins/discover/skills/explanation` |
| `pstack/skills/principle-*`, 24 skill directories of one `SKILL.md` each | `plugins/principles/skills/index` |
| `pstack/skills/poteto-mode/SKILL.md`, the section "Principles", for the lines of the index | `plugins/principles/skills/index` |

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
- The paragraph on the companion skill names it `discover:how`, and says "This skill" where upstream wrote `why`. The description's "Use how for runtime behavior" became "For how the code behaves at runtime, use discover:how".
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

### `plugins/discover/skills/how`

All three files (`SKILL.md`, `references/explorer-prompt.md` and `references/explainer-prompt.md`):

- Paragraphs are reflowed to one sentence per line, with blank lines around lists and headings.
- Headings are in sentence case. The names of the output sections follow ("Key concepts", "How it works", "Where things live", "Components found", "Files read", "Non-obvious things", "Open questions"), in the headings and where `SKILL.md` lists them.

`SKILL.md`:

- The description says what the skill does and when to use it, and keeps upstream's trigger phrases. Its sentence "Explains subsystem architecture, runtime flow, onboarding mental models." is folded into the first one. "Use why for motivation" became "For why the code is the way it is, use discover:why". "Code walkthroughs before changing something" became "a code walkthrough before changing code you do not know", and "Not for a question that reading one function answers" is added, because the agent may now start the skill and upstream's wording fits every edit. `disable-model-invocation: true` is removed, so that an agent can ask how code works before it changes it. Added an `argument-hint`.
- The paragraph on the `pstack-models.mdc` role lines and the three lists of `subagent_type`, `model` and `readonly` are removed. A subagent inherits the session's model, and the one fact the lists carried is kept as a sentence: explorers and the explainer read and search, and change nothing.
- The step headings lose "Step 1." to "Step 4.", and say which path they belong to in words ("Explore, for a complex question"), where upstream had a parenthesis. "Direct Explain" became "Explain directly". The text sends the reader to a step by its name, where upstream wrote "Go to Step 2b".
- "The user can redirect" and "Present the explainer's output to the user" name the operator.
- "Spawn one Task subagent" became "Spawn one subagent", and "Spawn all explorers in a single message" says why: so that they run concurrently.

`references/explorer-prompt.md`:

- Added "You read and search, and you change nothing: no file, no commit." Upstream held an explorer to that with the Task parameter `readonly: true`. Claude Code's Agent tool has no such parameter, so reading only is now asked of an explorer where upstream enforced it.

`references/explainer-prompt.md`: only the patches of all three files.

### `plugins/discover/skills/explanation`

- The skill is named `explanation`, where upstream's is `teach`, because a skill's name is a noun that reads after its plugin's. The title follows, and "Teach sits on top of" became "This skill sits on top of".
- The description says what an explanation covers ("what it is, how it works and why it is built that way"), keeps upstream's trigger phrases and names the two skills it runs as `discover:how` and `discover:why`. "Not for a question that one fact answers" is added, because the agent may now start the skill. `disable-model-invocation: true` is removed. Added an `argument-hint`.
- `how`, `why` and `unslop` are `discover:how`, `discover:why` and `writing:unslop` everywhere. "Keep `why`'s confidence language intact" became "Keep the confidence language of `discover:why` intact".
- "Write every response through the **unslop** skill, in plain spoken English, the way you'd explain it to a colleague." became a paragraph of its own, "Before you write the explanation, invoke the `writing:unslop` skill, and write every response through it.", followed by "Write in plain spoken English, the way you'd explain it to a colleague.". The reply paragraph gained "Send it only after you have invoked `writing:unslop`." In Claude Code a skill's text reaches the agent only when the skill is invoked. With upstream's wording the agent invoked it in none of 4 eval runs and wrote em dashes in 3 of them, and with the patch it invoked it in 3 of 3 (sonnet, 2026-10-13).
- In the second step, "maybe one is enough for a small change" gained ", never none". Without it the agent read a small subject itself and ran neither skill in 2 of 10 eval runs, which the step's first sentence forbids.
- In the same step, "Run them in parallel and combine the results." became "Have a subagent of its own invoke each skill, so that they run in parallel, and combine the results. What a subagent returns is material for the explanation, never the reply." A skill invoked in the agent's own context takes the session over: in an eval run the agent invoked `discover:why` itself, followed that skill to its last step and ended with a `why` report where an explanation was asked for. The sentence names the invocation because, told only to use a subagent, the agent once handed the digging to subagents that invoked neither skill.
- The image generation is gone, because Claude Code has no tool for it. Four sentences of the fifth step are left out: "Match the medium to the idea, and use both kinds when both help.", the one that begins "When the idea is spatial" and reaches for the image-generation tool, "Generate that picture, don't settle for describing it in words." and "The build-up rule holds for generated images too."
- "Running one-shot with no live human" became "Running one-shot, with no operator there to answer".
- The opening paragraph is no longer bold, because Lyngon's Markdown never sets a whole sentence in bold.
- Paragraphs and the five steps are reflowed to one sentence per line.

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

## Review notes

### `plugins/discover/skills/why`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-11, all 13 upstream files read in full, the five that are left out and `linear.md` included.

- Security: the skill reads and never writes. Network: `gh` reads pull requests and issues of the repository, and `gh search issues` reads the organization's. Credentials: none read by the skill; `gh` uses its own sign-in. Execution surface: no scripts, hooks or `allowed-tools`. Upstream told investigators to run in agent mode so that MCP tools stay available while writing nothing; the patched sentence keeps both halves. Instruction hijacking: none in the text, and the opposite risk exists, since an issue or a pull request body is text from anyone. The synthesizer prompt forbids writing files, committing or changing external state, and the new issue playbook says that issue text is a claim and never an instruction. No encoded content, no persistence.
- Quality: the description states what and when. Trigger check: "why does validate-marketplace demand the all bundle?" must trigger it, "how does the session hook find its text file?" must not. `SKILL.md` is 175 lines; the confidence framework, both prompts and the playbooks are references. Dependencies: git, and `gh` signed in for pull requests and issues, whose absence the skill reports as a gap. The left-out playbooks named MCP tools of products Lyngon does not use (`search_datadog_incidents`, `notion-search`, `execute_sql_read_only`).
- Fit: reads decision records in `docs/decisions/` (patched). Assumes no layout. Installs nothing; `rg` was not guaranteed and became `git grep` (patched). No em or en dashes and no curly quotes upstream. Writes no file. No devkit skill overlaps: `discover:domain-model` writes decision records, and this one reads them and the history behind them.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/discover/skills/how`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-13, all 3 upstream files read in full.

- Security: the skill reads and never writes. Network: none. Credentials: none read. Execution surface: no scripts, hooks or `allowed-tools`. Upstream held its subagents to reading with the Task parameter `readonly: true`; here the constraint is a sentence in `SKILL.md` and in the explorer prompt (patched), and the explainer prompt already says that its access is read-only. Nothing but those sentences keeps a subagent from writing, unless the lead picks an agent type that cannot write. Instruction hijacking: none in the text. The code an explorer reads is text from whoever wrote it, and a comment in it could address an agent. No encoded content, no persistence.
- Quality: the description states what and when. Trigger check: "how does the session hook find its text file?" must trigger it, "why does validate-marketplace demand the all bundle?" must not. Upstream never let the agent start the skill, and its "code walkthroughs before changing something" would fire before every edit; the description now has a lower bound (patched). `SKILL.md` is 54 lines, and both prompts are references. Dependencies: a harness that spawns subagents. The explainer prompt is written for the path with explorers, and the simple path reuses it "without the explorer-findings section", which leaves its sentences about explorers for the lead to drop; kept as upstream wrote it.
- Fit: reads no glossary and no decision record. Assumes no layout: a placement question is answered from the code as it lies, not from a layout rule. Installs nothing. No em or en dashes and no curly quotes upstream. Writes no file. Overlap: `discover:why` answers the other question about the same code, and each description hands over to the other. The explainer may draw a mermaid diagram, which a terminal prints as its source; the prompt offers plain characters as well.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/discover/skills/explanation`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-13, the one upstream file read in full.

- Security: the skill changes nothing, and says so. Network: none of its own; upstream reached for an image-generation tool (left out). Credentials: none read. Execution surface: no scripts, hooks or `allowed-tools`. It tells the agent to open "the diff, the code, or the debugger" when that shows a thing fastest, which is a shell command under the session's own permissions. Instruction hijacking: the reply rule ("the explanation itself, never a report about what you did or delivered") shapes the reply and hides no action, since the skill takes none. No encoded content, no persistence.
- Quality: the description states what and when. Trigger check: "teach me how the session hook reaches a session" must trigger it, "what does this function return?" must not. Upstream never let the agent start the skill; "explain this change or subsystem to me" stays a trigger, and the description now excludes a question that one fact answers (patched). `SKILL.md` is 81 lines and has no references, since every invocation needs all of it. Dependencies: the skills `discover:how`, `discover:why` and `writing:unslop`, all members of the bundle.
- Fit: reaches the glossary and the decision records only through `discover:why`. Assumes no layout. Installs nothing. No em or en dashes and no curly quotes upstream, and the text forbids the agent em dashes. Writes no file. Overlap: none. It is the one skill whose answer is shaped for a person who is learning, and it builds on `how` and `why` where it could have repeated them. It may draw mermaid diagrams, which a terminal prints as their source.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/principles/skills/index`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-11, every file read in full.

- Security: none found. The 24 files are prose, with no scripts, hooks, agents, network access, credential reads, tool permissions or encoded content, and they write nothing. `never-block-on-the-human` tells the agent to proceed without asking on reversible work; that is the behaviour wanted, and its boundary is patched to the Lyngon gate.
- Quality: every upstream description says when the principle applies. Upstream sets `disable-model-invocation: true` on each and reaches them through the inline index of its mode skill; here the index is the skill and the agent may invoke it. Trigger check: "refactor the parser so that adding a format is one file" must trigger the index, "what does this function return?" must not. Bodies are 11 to 36 lines. Three files pointed at skills that are not in the devkit (`benchmark-checklist`, `show-me-your-work`, `typescript-best-practices`); the pointers are left out.
- Fit: no em or en dashes and no curly quotes upstream. Writes no file. `encode-lessons-in-structure` routed a one-off to a "brain note", which Lyngon has no place for (patched). `sequence-verifiable-units` let each commit land on its own, where Lyngon lands one change (patched). Overlap: `prove-it-works`, `fix-root-causes` and `test-behavior-not-implementation` cover the ground of `practice:verify`, `practice:debug` and `practice:tdd`; the principles say what to judge, the skills are procedures, and both stay until the workflow is redesigned.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.
