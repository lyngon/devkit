# pstack

- **Upstream**: <https://github.com/cursor/plugins>
- **Upstream commit**: 9f451cf875ad1239912762f67741e8e5ba6ac0f1
- **Upstream version**: 0.15.15 (`pstack/.cursor-plugin/plugin.json`)
- **Upstream license**: MIT (see [LICENSE-pstack](../../shared/LICENSE-pstack))
- **Reviewed**: 2026-10-27 by Anders Åström

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

### `plugins/build/skills/correction`

A correction that the repository does not keep lasts as long as the session it was given in.
The agent says it will remember, and the next session makes the mistake again.
`encode-lessons-in-structure` says that a mistake which repeats becomes a check, and this skill is the procedure for it: the levels to try in order, from architecture down to prose, and the demand that a check is shown failing on the real mistake.
Upstream remembers a mistake as a row of a rule table in the agent instruction file, which no agent writes in a Lyngon repository.
Here the memory is the mistake ledger, one dated file per first occurrence, so that a second occurrence is recognized as a repeat and a mistake that never repeats ages out.

### `plugins/writing/skills/technical`

Agents draft Lyngon's documents, pull request descriptions and commit messages, and the people who read them review many in a day.
`unslop` removes the patterns of machine-written prose, and says nothing about what kind of document a text is, whom a sentence addresses or how much it carries.
This skill is that standard, in four layers that each rest on a published one: Diátaxis, the Google developer documentation style guide, Simplified Technical English and Global English.
It is short enough to read before every document, it comes from the author of `unslop`, and it hands each document to that skill when the layers are done.

### `plugins/writing/skills/simpler`

An agent reports in the vocabulary of the work it just did, and the person who reads the report was not there.
This skill gives the request "say that again so that I follow" a name: the last message, restated shorter and without jargon.
It is three sentences, and it is vendored so that the request works the same in every repository.

### `plugins/build/skills/architect`

An agent that goes from a task straight to code builds the first shape it thought of, and a wrong shape shows only once code depends on it.
This skill puts the design first.
It grounds the design in the code it touches, sketches at least two whole shapes, screens them against red flags written for a codebase that agents change, and builds against the chosen sketch, with a rule for when to throw the sketch away.
It is where `exhaust-the-design-space`, `foundational-thinking` and `redesign-from-first-principles` become a procedure, and it ends at the gate on the design when the owner asks for one.

### `plugins/build/skills/arena`

One attempt at an artifact is one sample, and nothing tells the agent how good it was.
This skill runs several attempts at once, scores them against a rubric written before any was read, checks the scores against a judge on another model, and grafts the best parts of the others into the strongest.
`architect` sketches its candidates through it, and the operator can ask for it for any artifact.

### `plugins/build/skills/review`

An agent that reviews its own change shares its own blind spots, and a reviewer on the same model shares most of them.
This skill gives one change to reviewers on different models, with the same rubric and code-quality lens, and judges their findings into one verdict that says what to act on and what was dismissed, and why.
It runs only when the operator asks for it or `build:architect` puts a design under pressure, for a contested design or a change with a large blast radius.

## What was taken

| Upstream path | Destination |
| --- | --- |
| `pstack/skills/why` | `plugins/discover/skills/why` |
| `pstack/skills/how` | `plugins/discover/skills/how` |
| `pstack/skills/teach` | `plugins/discover/skills/explanation` |
| `pstack/skills/principle-*`, 24 skill directories of one `SKILL.md` each | `plugins/principles/skills/index` |
| `pstack/skills/poteto-mode/SKILL.md`, the section "Principles", for the lines of the index | `plugins/principles/skills/index` |
| `pstack/skills/correct` | `plugins/build/skills/correction` |
| `pstack/skills/technical-writing` | `plugins/writing/skills/technical` |
| `pstack/skills/bro` | `plugins/writing/skills/simpler` |
| `pstack/skills/architect` | `plugins/build/skills/architect` |
| `pstack/skills/arena` | `plugins/build/skills/arena` |
| `pstack/skills/interrogate` | `plugins/build/skills/review` |

The 8 principles of the group steering in `plugins/principles/skills/index` are written by Lyngon and have no upstream.
So is `scripts/prune-mistakes.py` in `plugins/build/skills/correction`.

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
- In the parallel path, "Launch them in a single message so they run concurrently." became "Launch them in a single message and in the foreground (`run_in_background: false` on each call), so that they run concurrently and every finding is back before you go on.", and the synthesizer is spawned "in the foreground (`run_in_background: false`)". The reason is the one given for the same patch under `plugins/discover/skills/how`. No eval run takes this path, since no run has a source beyond git and GitHub.
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
- "Spawn one Task subagent" became "Spawn one subagent".
- "Spawn all explorers in a single message" became "Spawn all explorers in a single message and in the foreground (`run_in_background: false` on each call), so that they run concurrently and every finding is back before you go on." The two steps that spawn one subagent say "in the foreground (`run_in_background: false`)". Claude Code's Agent tool starts a subagent in the background unless the call passes that parameter, and an agent whose subagents run in the background ends its turn to wait for them. When the agent is itself a subagent, that turn is the result its parent gets. Without the patch a subagent that ran this skill handed back "All four explorer agents are now running in the background. I'll wait for them to complete before synthesizing the findings.", and the session ended without the explanation in 3 of 6 runs of the eval case `explanation-of-a-subsystem`. With the patch it ended with the explanation in 6 of 6 (sonnet, Claude Code 2.1.283, 2026-10-13). The parameter is named at every step because "in the foreground" alone left the explorers in the background in 2 of 4 runs of `how-explores-a-subsystem`, and a single explainer in 2 of 3 runs of `how-explains-a-flow`. A session whose Agent tool has no such parameter runs every subagent in the background, and ignores the parameter in a call that passes it.

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
- The same step gained "Start those subagents in a single message and in the foreground (`run_in_background: false` on each call), so that what each returns is back before you go on." Without it the agent started them in the background in 5 of 6 runs of the eval case `explanation-of-a-subsystem` and ended a turn on a line such as "Both are running now" before the explanation. What a background subagent does one level down is under `plugins/discover/skills/how`.
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
- `encode-lessons-in-structure`: the route "One-off -> brain note. Recurring fix -> skill or lint rule. Systemic issue -> principle." became: a first occurrence that a person caught goes into the mistake ledger, as a file under `docs/mistakes/` that `build:correction` writes, one that a test or a check caught needs no file, a repeat gets the strongest check that works, and a repeat that no tool can decide becomes a principle, which in a repository is a file under `.claude/rules/`. Step 3 of the pattern follows it: "make the instruction more prominent and add an example of the failure mode" became "make it a principle and name the failure it prevents". Added the sentence "A rule without a check is debt." to the corollary. "Apply now or create a concrete todo" became "Apply now, or file an issue with the evidence", because an agent does not defer work into a file on its own. "When the human intervenes" became "When the owner or the operator intervenes", and "a brain note" in the anti-patterns became "a note".
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

### `plugins/build/skills/correction`

- The skill is named `correction`, where upstream's is `correct`, because a skill's name is a noun that reads after its plugin's. The title follows.
- The description says what happens to a first occurrence and to a repeat, and keeps upstream's order of levels and its demand for proof, with "write docs last" as "prose last". "Repeat this each time the operator corrects you" became "Use each time the operator corrects you, a review finding is accepted or a change is reverted". "Use for /correct" became "for 'correct' or 'find the mistakes agents keep repeating'", since the slash command has another name here. "Not for a check or a test that failed" is added. `disable-model-invocation: true` is removed, because only the agent can start the skill when it is corrected. Added an `argument-hint`.
- "this repo" and "the repo" became "this repository" and "the repository".
- "Find the mistake classes" opens with the three events that hand the agent a mistake, and says that a check or a test that failed hands it none. Upstream's reading list follows as what to read when asked for the mistakes agents keep repeating, with "agent instruction files" changed to "the rule files under `.claude/rules/`". Added that the agent reads every file of the ledger before it writes anything, "and the ledger holds the ones that have happened once" to upstream's "A class counts once it has happened twice", and that a ledger file counts whatever its date.
- The fourth level, "Write docs or agent rules last, only for judgment calls. Nothing fails when an agent skips them.", became "Write a principle last, only for judgment calls. Nothing fails when an agent skips it." Added where the principle goes, a rule file under `.claude/rules/`, and that the pull request names the file, because the owner approves the principles of the repository.
- "a human's approval" of an exception became "the owner's approval".
- The section "Keep the rule table" became "Keep the mistake ledger". Upstream keeps a table in the agent instruction file that pairs each rule with what enforces it, adds a rule at each correction and drops it once its mistake can't happen. Here a mistake that has happened once is a file under `docs/mistakes/`, in the shape the section gives, and the line **Caught in** waits for the pull request to exist. Added that `validate-documents` fails a file of another shape.
- Added the paragraph on `scripts/prune-mistakes.py` at the end of that section: the agent prunes when everything else is done and never before it has read the ledger, commits what the script deleted, and reports a script that cannot run or refuses. Pruning comes last because a repository may go untouched for longer than the limit, and pruned first, a mistake that came back would look new. Upstream's "If the rule was already there and nothing enforces it, that's a repeat, so fix it at the highest level in the same change" became "If the mistake was already in the ledger, that's a repeat, so fix it at the highest level in the same change and delete its file".
- The reply names the ledger file for a first occurrence, and for a repeat adds "the check failing on the past mistake" to upstream's level and reason.
- Paragraphs are reflowed to one sentence per line. The four levels keep upstream's lines.

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

### `plugins/build/skills/architect`

All four files (`SKILL.md`, `references/runner-prompt.md`, `references/rationale-template.md` and `references/design-red-flags.md`):

- Paragraphs are reflowed to one sentence per line, with blank lines around lists and headings. The italic notes of the rationale template keep their emphasis around all their sentences.
- A principle is named as in "the principle `boundary-discipline`", where upstream wrote "the **boundary-discipline** principle skill".

`SKILL.md`:

- The description says what the skill does and when to use it, and keeps upstream's trigger phrases "architect this" and "design this", with "sketch the types first" added. "Use for /architect" is gone, since the slash command has another name here. Upstream's "or non-trivial work where jumping to code would lock in the wrong shape" became "Use only when the operator asks for it or for a design", followed by "Asking for a design counts as asking for this skill" and "Not on your own initiative for a task that asks for no design". `disable-model-invocation: true` is removed, so that the agent can start the skill when the operator asks for a design in words. Without the flag, upstream's last clause would have let the agent start the skill, and with it several subagents, on most coding tasks. Added an `argument-hint`.
- The section "Start" and its todo list are removed.
- The headings lose "Phase A:" to "Phase E:", and the text names a step where upstream named its letter. "Phase A evidence" became "grounding evidence", "Re-ground and re-run Phase B" became "Ground the problem again and sketch again", "Return to Phase B and re-run arena" became "Return to "Sketch" and invoke `build:arena` again", and the tell "Two or more independent Phase D deviations" lost "Phase D". The heading "Agree (opt-in)" lost its parenthesis.
- Added the two sentences that say that the principles the skill names are files of `principles:index`, to be read before they are applied.
- Added the paragraph on the design file, which holds the sketch and its rationale, is committed on the branch, and is removed by the build plugin when the work is finished. It is the branch's own file under `docs/plans/` when the branch has one, such as the file of a `discover:approach` session, and a new `docs/plans/YYYY-MM-DD-<slug>.md` otherwise. Upstream said that the rationale "ships alongside" and named no place. The owner chose the design file over a scratch file under `tmp/` in the review of this change, so that the rationale has one place with a gate and without one. "Sketch" ends with "Write the package into the design file, then continue with "Agree" below", and "Outputs" says that the rationale ships alongside "in the design file".
- "Run the **how** skill over the relevant subsystems" became "Have a subagent of its own invoke `discover:how` over the relevant subsystems, started in the foreground (`run_in_background: false`). What it returns is your grounding, never the reply." The same holds for `discover:why`, and two subagents started together go "in a single message and in the foreground (`run_in_background: false` on each call)". A skill invoked in the agent's own context takes the session over, as `discover:why` did in the evals of `discover:explanation`, and here that would end the skill after its first step. "Produce the traced model `how` prescribes" became "The grounding is the traced model that `discover:how` prescribes", since the subagent produces it. The first step of "When you scrap" follows: "Have a subagent invoke `discover:how` over what's been built, started in the foreground (`run_in_background: false`), as in "Ground the problem"", where upstream wrote "Re-run the **how** skill over what's been built". Why the foreground is named, with its parameter, is under `plugins/discover/skills/how`.
- `build:arena` and `build:review` run in the lead's own context, where `discover:how` and `discover:why` go to subagents. The lead starts the runners and the judge of an arena itself, and continues from its synthesized package, and a review's verdict changes the sketch that the lead holds. What keeps the lead in this skill afterwards is the sentence that ends each of the two steps, "then continue with "Agree" below" and "then continue here", and the eval case `architect-stops-at-the-design-gate` grades the steps after the arena: the design file written and committed, and one question.
- The paragraph on the `architect runners` line of the `pstack-models.mdc` rule, its two model names and its rules for alias and rejected entries are removed. The runners follow the rules of `build:arena`.
- "Run the **arena** skill with the design-sketch task and the Phase A grounding artifacts" became "Invoke `build:arena` with the design-sketch task and the path of the grounding", after the added sentence "Write the grounding to `tmp/arena/<task>/grounding.md`, in the directory `tmp/` at the root of the repository." `build:arena` gives each candidate "the path to the shared grounding", and upstream named no file for it. "Arena returns" became "`build:arena` returns", and "the rationale's "Synthesis decision" section" became "the rationale's section "Synthesis decision"".
- "Pass `references/runner-prompt.md` as each runner's prompt." became "Pass the part of `references/runner-prompt.md` below its line `---` unchanged as each runner's prompt, with the task, the grounding and the paths filled in around it." The runner prompt says that the orchestrator passes it through, and in `build:arena` the same prompt for every candidate is the contract. The reason for the line is under `references/runner-prompt.md` below.
- The checkpoint that the invoker opted into ("/architect with checkpoint," "stop and show me before implementing," or similar) became the gate that the workflow design names: stop when the owner asked for a gate on the design, "as in "show me the design before you implement" or "stop and show me before implementing"". "Then surface the synthesized design and pause for sign-off" became the sentences that take its place: until the owner approves, the sketch lives in the design file only and nothing else in the repository changes, and the agent commits the design file on the branch and stops with one question, "the last sentence of your reply", whether the owner approves the design. Without those words 1 of 10 runs of the eval case `architect-stops-at-the-design-gate` ended on "Let me know if this design has your approval", with no question. "Default: proceed directly to implementation with the synthesized design. No human checkpoint." became "By default, go on to implementation with the synthesized design, without stopping.", since `CONCEPTS.md` lists "checkpoint" as a term to avoid. "The synthesis can ship as its own commit either way" became "After the gate, or at once when there is none, the sketch can ship as its own commit".
- "For adversarial pressure on the design before implementing, run the **interrogate** skill on the synthesized sketch." became "For adversarial pressure on the design before implementing, when the design is contested or its blast radius is large, invoke `build:review` on the synthesized sketch. Fold the findings you act on into the sketch and the design file, then continue here." The condition is the one the workflow design gives for `build:review`. That skill applies no change, so the added sentence says what becomes of its verdict.
- "If the human pushes back on the shape (in a checkpoint or after the fact)" became "If the owner or the operator pushes back on the shape, at the gate or after the fact".
- "the whole repo" became "the whole repository", and the link to `design-red-flags.md` has the file's name as its text.

`references/runner-prompt.md`:

- "Read the **architect** skill in full first. That's the workflow you're inside." became "The lead runs that skill and `build:arena`, so invoke neither: your job is this one candidate." In Claude Code a runner reads a skill by invoking it, and an invoked `build:architect` would start the whole workflow inside the runner, an arena of its own included.
- "during Phase B" became "during the step "Sketch"".
- Added a line `---` between the paragraph for the orchestrator and the text for the runner, as the reviewer prompt of `build:review` has, and "passes this file through to every parallel candidate runner" became "passes the part of this file below the line to every parallel candidate runner ..., unchanged". Upstream's file holds both with nothing between them. In 2 of 7 runs of the eval case `architect-stops-at-the-design-gate` whose traces were kept, the lead wrote the runners a prompt of its own: once with the discipline reworded for the task, once with the paragraph for the orchestrator dropped and the runner's opening sentences reworded (sonnet, 2026-10-27).
- What the orchestrator fills in is "the grounding", where upstream wrote "the Phase A grounding artifacts", "the candidate's own working directory", where it wrote "the isolated working directory", and also the path of `rationale-template.md`, since a subagent cannot follow a link relative to a file that it was never given. The link to that file became its name.
- The working directory is "a git worktree or a directory of its own under `tmp/arena/` at the root of the repository, as `build:arena` decides", where upstream wrote "a git worktree when available, otherwise a per-runner subdirectory under the sketch dir".
- "in architect's parallel exploration" became "in the parallel exploration of `build:architect`", and "each on a different model" gained "where the harness offers more than one".
- Added "The principles named below are files of `principles:index`; read each one you apply."

`references/rationale-template.md`:

- The link "[Phase A](../SKILL.md#phase-a-ground-the-problem)" became "[grounding the problem](../SKILL.md#ground-the-problem)", and "Filled in by [arena](../../arena/SKILL.md)" became "Filled in by `build:arena`".
- "the human" and "the human's answer" name the owner.
- "(or after Phase D sign-off, if a checkpoint was opted into)" became ", or after the owner approved the design when they asked for a gate". Upstream's checkpoint is its Phase C, and its Phase D is the implementation.

`references/design-red-flags.md`: only the reflow.

### `plugins/build/skills/arena`

- Paragraphs are reflowed to one sentence per line, with blank lines around lists and headings. A numbered step keeps its sentences on one line.
- The description says what the skill does, with the judge, and keeps upstream's trigger phrases "arena this" and "throw it in the arena". "Use for /arena" is gone. Upstream's "or when one attempt at a non-trivial artifact would lock in the wrong shape" became "Use only when the operator asks for it, ..., or when build:architect sketches a design. Not on your own initiative." `disable-model-invocation: true` is removed, because `build:architect` invokes the skill and the Skill tool refuses a flagged one. Added an `argument-hint`.
- The section "Start" and its todo list are removed.
- The headings lose "Phase A:" to "Phase F:", and the text names a step where upstream named its letter: "in Phase D" became "in "Pick a base"", "Phase A was under-specified" and "Phase A was wrong" name the framing, "Reframe and re-run" and "re-frame and re-run" became "Frame again and run again", and "go back to Phase E" became "go back to "Graft"".
- Added the two sentences that say that the principles the skill names are files of `principles:index`. A principle is named as in "the principle `boundary-discipline`", and "per the Laziness Protocol" became "per the principle `laziness-protocol`".
- "3-6 concrete gradeable criteria" became "3 to 6".
- The step "Pick the runners" lost the `arena runners` line of `~/.cursor/rules/pstack-models.mdc`, its two default models, the meaning of `auto` and `inherit-parent`, and the fallbacks for a rejected entry. It says "By default there are two, each on a different model where the harness offers more than one (the Agent tool's `model`), and none on a weaker model than yours." Upstream's two default runners and its judges are of the strongest tier of two families, `claude-opus-5-5-xhigh` and `grok-4.7-xhigh-fast`. Without the words on strength, a trial run of the eval case `arena-picks-a-base-and-grafts` put the judge on haiku while the lead ran on sonnet, and so did one of `architect-stops-at-the-design-gate` (2026-10-27). "Same model N times" became "Use the same model for every runner".
- The step "Assign output paths" became "Give each candidate a place of its own". A candidate whose artifact is a change to the repository's files works in a git worktree of its own, which the Agent tool's `isolation: "worktree"` gives it, and every other candidate, "a draft or a sketch among them", writes to `tmp/arena/<task>/candidate-<n>/`, as does one whose harness offers no worktree. Upstream wrote to `/tmp/arena-<slug>/candidate-<n>/`, outside the repository, where `tmp/` is the agent scratch directory that a Lyngon repository ignores. Added "That `tmp/` is the directory at the root of the repository that holds agent scratch, never the system's temporary directory." Without it, the trial run of `arena-picks-a-base-and-grafts` read `tmp/arena/` as the system's temporary directory, looked up `TMPDIR`, and wrote the candidates and the synthesis note there.
- "Spawn all N subagents in one message with `run_in_background: true`" became "Spawn all N candidates in a single message and in the foreground (`run_in_background: false` on each call), so that they run concurrently and every candidate is back before you go on." The skill builds its result from its subagents, and the reason is the one given for the same patch under `plugins/discover/skills/how`. "the synthesis record" became "the synthesis note".
- Added to "Fan out": "When the skill that invoked this one names a prompt for the candidates, as `build:architect` does with its runner prompt, each candidate gets that prompt's text unchanged, with these inputs filled in around it." With the sentence in `build:architect` alone, the eval grader that looks for the runner prompt in the candidates' prompts still failed in 1 of 3 runs. The candidates are started while this skill's text is the latest in the context, and its own list of what each candidate gets reads as the whole prompt.
- Upstream starts the cross-judge, a readonly subagent on a model from the line `arena cross-judge pool` (or one of two defaults) of another family than the parent's, while the parent reads the candidates for Phase D, and says not to start it while candidates are still writing. Here the lead reads every candidate end to end first, scores each against the rubric and starts the synthesis note with the scores, and then starts the judge in the foreground (`run_in_background: false`), "on a different model than yours that is no weaker, where the harness offers one". Why "no weaker" is under the step "Pick the runners" above. Upstream kept the two verdicts apart by running them at the same time. A judge in the foreground returns before the lead reads on, so the lead would score with the judge's verdict in view, and the order keeps them apart instead. "Read every candidate end to end before picking" and "Score each candidate against the rubric criterion by criterion, not on holistic feel" moved here from "Pick a base". The sentence on the judge running "in parallel with the parent's reading" is gone, and "readonly" became the sentence "The judge reads and changes nothing", since the Agent tool has no such parameter.
- "Compare against the cross-judge" became "Compare your scores with the judge's", and the pick is recorded "in the synthesis note, including the judge's verdict", where upstream wrote "in a short synthesis note alongside the base artifact, including the cross-judge's verdict".
- The synthesis note is `tmp/arena/<task>/synthesis.md`, scratch that is never committed, and the reply gives what it says. Upstream put it "alongside" the artifact. Added the paragraph on the worktree and the branch that the harness keeps for a candidate that changed something: the lead removes both once the synthesized artifact is verified.

### `plugins/build/skills/review`

All five files (`SKILL.md`, `references/reviewer-prompt.md`, `references/rubric.md`, `references/code-quality-review.md` and `references/lead-judgment.md`):

- Paragraphs are reflowed to one sentence per line, with blank lines around lists and headings. A bullet or a numbered item keeps its sentences on one line.
- Headings are in sentence case, and so are the names of the buckets and sections where the text mentions them ("Act on", "Agreement map").
- "PR" became "pull request".

`SKILL.md`:

- The skill is named `review`, where upstream's is `interrogate`, because a skill's name is a noun that reads after its plugin's. The title follows.
- Upstream's description is its trigger phrases and the sentence "Multiple LLM reviewers challenge changes from independent angles." It became what the skill does (reviewer subagents on different models with the same prompt, rubric and code-quality lens, one verdict in four buckets, no change applied) and when: "Use only when the operator asks for it", with all seven upstream trigger phrases, "or when build:architect puts a design under pressure", and "Not the routine review of every change". `disable-model-invocation: true` is removed, because `build:architect` invokes the skill and the Skill tool refuses a flagged one. Added an `argument-hint`.
- The headings lose "Step 1," to "Step 5,", and "from Step 2" in the output format became "from "State the intent"". "Determine Scope" became "Determine the scope", and "PR description" became "The pull request description".
- "the user" became the operator, in "Determine the scope", "State the intent" and the bucket "Consider".
- "Spawn one reviewer per configured model" became "Spawn one reviewer per model", and "Each model gets the same prompt and rubric" became "Each reviewer gets the same prompt and rubric".
- Added "The design file under `docs/plans/` if the branch has one" to the sources of the intent.
- The step "Spawn reviewers" lost the `interrogate reviewers` line of `~/.cursor/rules/pstack-models.mdc`, the table of default models (Reviewer A on `claude-opus-5-5-xhigh`, Reviewer B on `grok-4.7-xhigh-fast`), the Task tool's parameters `subagent_type`, `model` and `readonly`, the fallbacks for a rejected entry, and the instruction to "open a separate PR to update the default table". It says: spawn two reviewers in a single message and in the foreground (`run_in_background: false` on each call), give each a different model where the harness offers more than one (the Agent tool's `model`), none of them weaker than the model that did the work and at least one of them different from it, and "Reviewers read and search, and they change nothing". The foreground has the reason given under `plugins/discover/skills/how`, and "none of them weaker" the one given under `plugins/build/skills/arena`: upstream's two default reviewers are of the strongest tier of their families.
- The line of the output format "Reviewer [label]: [model name], [N findings]" became "[Model name]: [N findings]", since the labels A and B went with the table.

`references/reviewer-prompt.md`:

- Added "You read and search, and you change nothing: no file, no commit." Upstream held a reviewer to that with the Task parameter `readonly: true`.
- The example of the output names its language, `markdown`.

`references/lead-judgment.md`:

- "The configured reviewers" became "The reviewers", and "the user" became the operator.

`references/rubric.md` and `references/code-quality-review.md`: only the patches of all five files.

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
- Fit: reaches the glossary and the decision records only through `discover:why`. Assumes no layout. Installs nothing. No em or en dashes and no curly quotes upstream, and the text forbids the agent em dashes. Writes no file. Overlap: none. It is the one skill whose answer is shaped for a person who is learning, and it builds on `how` and `why` where it could have repeated them. `writing:simpler` restates a message that is already written, and digs for nothing. It may draw mermaid diagrams, which a terminal prints as their source.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/principles/skills/index`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-11, every file read in full.

- Security: none found. The 24 files are prose, with no scripts, hooks, agents, network access, credential reads, tool permissions or encoded content, and they write nothing. `never-block-on-the-human` tells the agent to proceed without asking on reversible work; that is the behaviour wanted, and its boundary is patched to the Lyngon gate.
- Quality: every upstream description says when the principle applies. Upstream sets `disable-model-invocation: true` on each and reaches them through the inline index of its mode skill; here the index is the skill and the agent may invoke it. Trigger check: "refactor the parser so that adding a format is one file" must trigger the index, "what does this function return?" must not. Bodies are 11 to 36 lines. Three files pointed at skills that are not in the devkit (`benchmark-checklist`, `show-me-your-work`, `typescript-best-practices`); the pointers are left out.
- Fit: no em or en dashes and no curly quotes upstream. Writes no file. `encode-lessons-in-structure` routed a one-off to a "brain note", which Lyngon has no place for (patched). `sequence-verifiable-units` let each commit land on its own, where Lyngon lands one change (patched). Overlap: `prove-it-works`, `fix-root-causes` and `test-behavior-not-implementation` cover the ground of `practice:verify`, `practice:debug` and `practice:tdd`; the principles say what to judge, the skills are procedures, and both stay until the workflow is redesigned.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/build/skills/correction`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-13, the one upstream file read in full.
Read by Anders Åström on 2026-10-13.

- Security: Network: none. Credentials: none read. Execution surface: no scripts, hooks or `allowed-tools` upstream. The skill changes the repository on purpose (code, types, lints, checks, tests) and commits. Here it also runs `scripts/prune-mistakes.py`, written by Lyngon, which deletes Markdown files directly in `docs/mistakes/` of the working directory, reads the date of every one of them before it deletes any, refuses outside the root of a repository, and starts no other program. A `docs/mistakes` that is a link to another directory is followed. Instruction hijacking: none in the text. What the skill reads for mistakes (review comments, commit messages, the ledger) is text from anyone, so a planted mistake could steer an agent into writing a check or a rule file; both reach the owner in a pull request. No encoded content. Persistence: nothing outside the repository.
- Quality: the description states what and when. Trigger check: "no, never edit the generated client by hand, change the schema" must trigger it, "the unit tests fail on main, find out why" must not. Upstream never let the agent start the skill and yet told it to "repeat this each time the operator corrects you", which only the agent can do (patched). `SKILL.md` is 65 lines and has no references, since every invocation needs all of it. Dependencies: git history, and `gh` for review comments. The script needs Python and the variable `LYNGON_MISTAKES_MAX_AGE_DAYS`, and the baseline provides both, through `lyngon.scriptTools` and `lyngon.mistakes.maxAgeDays`.
- Fit: upstream keeps its rule table in "the agent instruction file", which an agent never writes in a Lyngon repository (patched to the ledger). For a class that no tool can decide the skill writes a rule file under `.claude/rules/`, which the checklist reserves for the owner; the file reaches the owner in the pull request, which the skill tells the agent to name it in (patched). Assumes no layout. Installs nothing. No em or en dashes and no curly quotes upstream. Overlap: `encode-lessons-in-structure` states the principle and sends a first occurrence here, and this skill is the procedure.
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

### `plugins/build/skills/architect`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-27, all 4 upstream files read in full.
Read by Anders Åström on 2026-10-27.

- Security: Network: none. Credentials: none read. Execution surface: no scripts, hooks or `allowed-tools`. The skill writes code on purpose, since it builds what it sketched, and through `build:arena` it starts subagents that write. Upstream's candidates wrote under `/tmp/`, outside the repository (patched, see `plugins/build/skills/arena`). Instruction hijacking: upstream proceeds to implementation with "No human checkpoint" by default, which is the behaviour `never-block-on-the-human` asks for and hides nothing; its checkpoint is patched to the gate on the design. No encoded content. Persistence: nothing outside the repository after the patch.
- Quality: the description states what and when. Trigger check: "architect this: a plugin loader for the CLI, sketch the types before any code" must trigger it, "add a --verbose flag to the CLI" must not. Upstream never let the agent start the skill, and its "non-trivial work where jumping to code would lock in the wrong shape" fits most coding tasks once the flag is gone (patched). `SKILL.md` is 83 lines upstream with three references, the runner prompt, the rationale template and the red flags. Dependencies: the skills `discover:how`, `discover:why`, `build:arena` and `build:review`, and twelve principles of `principles:index` (six named in `SKILL.md` and six in the runner prompt), all in the bundle. Upstream's rationale template sends the reader to "Phase D sign-off" for the checkpoint, which is Phase C (patched).
- Fit: reads no glossary of its own and reaches the decision records through `discover:why`. Assumes no layout. Installs nothing. No em or en dashes and no curly quotes upstream, and no character outside ASCII. Writes no `AGENTS.md`, `CLAUDE.md`, file under `.claude/` or `.mcp.json` of its own; the harness puts a worktree that `build:arena` asks for under `.claude/worktrees/`, which git ignores. Upstream named no place for the rationale, and here it is the design file under `docs/plans/` (patched). No line carries a term that `scripts/validate-shipped-text.py` lists. Overlap: `discover:approach` settles a design with the owner in an interview and writes the design file, `build:plan` turns a settled design into tasks, and this skill explores whole shapes through candidates and then builds. All three stay until the workflow piece decides otherwise.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/build/skills/arena`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-27, the one upstream file read in full.
Read by Anders Åström on 2026-10-27.

- Security: Network: none. Credentials: none read. Execution surface: no scripts, hooks or `allowed-tools`. The skill starts several subagents that write, upstream in the background (patched to the foreground) and under `/tmp/arena-<slug>/`, outside the repository (patched to a worktree or `tmp/arena/`). Upstream held the judge to reading with the Task parameter `readonly`; here that is a sentence, and nothing but the sentence keeps the judge from writing. Instruction hijacking: none in the text. A candidate's output is text the lead reads and the judge scores, and it could address either; the rubric is written before any candidate is read. No encoded content. Persistence: a worktree and a branch per candidate that changed something, kept by the harness, which the lead removes once the result is verified (patched).
- Quality: the description states what and when. Trigger check: "arena this: the quickstart section of the README" must trigger it, "write the quickstart section of the README" must not. Upstream's "when one attempt at a non-trivial artifact would lock in the wrong shape" would let the agent start several subagents on most tasks once the flag is gone (patched). `SKILL.md` is 71 lines with no references. Dependencies: a harness that spawns subagents and, for the judge and the runners, a choice of models. Upstream draws its runners and its judge from two model families; Claude Code offers Claude models only, so the candidates and the judge differ less than upstream's. No patch can restore that, and the skill still works with one model, as upstream allows for generation-bound work.
- Fit: reads no glossary and no decision record. Assumes no layout. Installs nothing. No em or en dashes and no curly quotes upstream, and no character outside ASCII. No line carries a term that `scripts/validate-shipped-text.py` lists. Writes nothing it commits: the candidates and the synthesis note are scratch. Overlap: none in the devkit.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/build/skills/review`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-27, all 5 upstream files read in full.
Read by Anders Åström on 2026-10-27.

- Security: the skill reads and never writes, and says "Do NOT auto-apply changes". Network: none. Credentials: none read. Execution surface: no scripts, hooks or `allowed-tools`; the lead runs `git diff`. Upstream held its reviewers to reading with the Task parameter `readonly: true`; here that is a sentence in `SKILL.md` and in the reviewer prompt (patched), and nothing but the sentences keeps a reviewer from writing. Instruction hijacking: the diff under review is text from whoever wrote it, and a comment in it could address a reviewer. Upstream told the agent to "open a separate PR to update the default table" when a model name was rejected, an outward action as a side effect of a review (left out with the table). No encoded content, no persistence.
- Quality: the description states what and when. Trigger check: "interrogate the changes on this branch" must trigger it, "summarize what this branch changes" must not. Upstream's description is its trigger phrases and one sentence on what it does (patched). `SKILL.md` is 109 lines upstream; the rubric, the code-quality lens, the reviewer prompt and the lead's framework are references. Dependencies: git, a harness that spawns subagents, and a choice of models. The adversarial signal comes "from model diversity, not assigned personas", and upstream's two reviewers are of two model families. Claude Code offers Claude models only, so the reviewers differ less than upstream's, which no patch can restore.
- Fit: reads no glossary and no decision record, and reads the design file of the branch for the intent (patched). Assumes no layout. Installs nothing. No em or en dashes and no curly quotes upstream, and no character outside ASCII. No line carries a term that `scripts/validate-shipped-text.py` lists. Writes no file. Overlap: `review:request` sends one reviewer over a commit range before every pull request, and `review:receive` weighs review feedback, which the lead does here for the reviewers' findings. Both stay until the workflow piece removes the plugin `review`, and this skill runs only when the operator asks for it or `build:architect` puts a design under pressure. Until then `build:review` and the plugin `review` share a word.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.
