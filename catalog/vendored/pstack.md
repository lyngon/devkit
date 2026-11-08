# pstack

- **Upstream**: <https://github.com/cursor/plugins>
- **Upstream commit**: 9f451cf875ad1239912762f67741e8e5ba6ac0f1
- **Upstream version**: 0.15.15 (`pstack/.cursor-plugin/plugin.json`)
- **Upstream license**: MIT (see [LICENSE-pstack](../../shared/LICENSE-pstack))
- **Reviewed**: 2026-10-28 by Anders Åström

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

### `plugins/build/skills/work-trace`

Work that runs for hours, or while the owner is away, ends in a diff and a summary, and the summary is the agent's own account of what it did.
Nothing in it says which forks it took, which attempts it threw away, or whether a check it reports was ever run.
This skill keeps that account as it happens, one row per decision with a pointer to its evidence, checks the rows against the session's transcript at the end, and has a reviewer on another model point out what the owner should look at.
It is the trail that `prove-it-works` and `build:figure-it-out` send their work to.

### `plugins/build/skills/benchmark`

A performance number that went wrong still looks like a number: a cache that skipped the work, failed requests that came back fast, a side left on debug settings, noise wider than the gap.
`explain-the-number` says why such a number cannot be trusted, and this skill is the procedure for one: seven questions, each answered from a run, and a report that leads with the verdict and carries the run count, the range and the limiter.

### `plugins/build/skills/figure-it-out`

A large migration or a change of many parts fits none of the procedures the devkit has, and an agent that starts it without a design finds the hard part last.
This skill designs the run first: a falsifiable definition of done, a rigor level, units sequenced riskiest first with the verification harness and its baseline ahead of them, and then a loop that keeps or reverts each unit on evidence.
It builds on `build:architect` for the one-way doors and on `build:work-trace` for the trail.

### `plugins/build/skills/clean-comments`

An agent comments the code it writes: it narrates what a line does, keeps the old version commented out, and explains a workaround where it should have removed it.
`reshape-instead-of-commenting` and `record-what-the-code-cannot-show` say which comments may stay, and nothing checks a change against them.
This skill has a fresh subagent delete every comment of a change that its list of exceptions does not protect and flag the code that a deleted comment was covering for, then vets the result and fixes the flags at their root.

### `plugins/build/agents/comment-auditor.md`

The subagent of `build:clean-comments` is an agent definition of its own, so that it starts from its rules and a scope, and from nothing of the session that wrote the comments.
It deletes and flags, and leaves every change to the code to the skill that spawned it.

### `plugins/build/skills/auto`

Under the standing instructions an agent decides and acts, and invokes the skills whose triggers match.
Some tasks deserve more: a route to the playbook for their kind, delegates that write the code while the lead reviews, and a reply in which every claim carries its proof.
This skill is that mode, which the operator switches on for one task.
It is the mode of the author of the principles the devkit builds on, with Cursor's machinery taken out and what every change needs moved to the standing instructions, so that a session without the mode lacks nothing it must do.
Its five playbooks each say, for one kind of task, what must hold when it is done and what proof is owed.

### `plugins/build/skills/pull-request`

A change lands as one squash commit whose subject and message are the title and the body of its pull request, so the pull request is the record that the default branch keeps.
This skill is upstream's playbook for opening one, made a skill so that every session reaches it without the mode.
It holds the body to the seven sections that `check-pull-request` checks, and posts the branch's work trace where the owner reviews.

### `plugins/build/skills/tdd`

A bug fixed without a test that failed first can come back unnoticed, and a test written after the fix may never have failed.
This skill writes the failing test first when the bug has a cheap test path, and no test rather than a bad one when it has not.
It replaces the rule of superpowers that no production code is written without a failing test, as the roadmap of the philosophy overhaul settled.

### `plugins/build/agents/implementer.md`

The mode delegates code to a subagent and reviews its diff.
A skill that only the operator can start cannot be preloaded into a subagent, so the delegate is an agent definition of its own that reads the mode's file before any work, builds its scope and leaves the hand-over to the lead.

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
| `pstack/skills/show-me-your-work` | `plugins/build/skills/work-trace` |
| `pstack/skills/benchmark-checklist` | `plugins/build/skills/benchmark` |
| `pstack/skills/figure-it-out` | `plugins/build/skills/figure-it-out` |
| `pstack/skills/no-comments` | `plugins/build/skills/clean-comments` |
| `pstack/agents/comment-sicko.md` | `plugins/build/agents/comment-auditor.md` |
| `pstack/skills/poteto-mode/SKILL.md`, every section but "Principles" | `plugins/build/skills/auto` |
| `pstack/skills/poteto-mode/playbooks/feature.md` | `plugins/build/skills/auto/playbooks/feature.md` |
| `pstack/skills/poteto-mode/playbooks/refactoring.md` | `plugins/build/skills/auto/playbooks/refactoring.md` |
| `pstack/skills/poteto-mode/playbooks/bug-fix.md` | `plugins/build/skills/auto/playbooks/bug-fix.md` |
| `pstack/skills/poteto-mode/playbooks/prototype.md` | `plugins/build/skills/auto/playbooks/prototype.md` |
| `pstack/skills/poteto-mode/playbooks/autonomous-run.md` | `plugins/build/skills/auto/playbooks/autonomous-run.md` |
| `pstack/skills/poteto-mode/playbooks/opening-a-pr.md` | `plugins/build/skills/pull-request` |
| `pstack/skills/tdd` | `plugins/build/skills/tdd` |
| `pstack/agents/poteto-agent.md` | `plugins/build/agents/implementer.md` |

The 9 principles of the group steering in `plugins/principles/skills/index` are written by Lyngon and have no upstream.
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
- `explain-the-number`: "run the full procedure with the [benchmark-checklist](../benchmark-checklist/SKILL.md) skill" became "run the full procedure with `build:benchmark`", and the sentence on an eval result that follows it starts a line of its own.
- `prove-it-works`: "Keep the artifact visible for the human" became "for the owner". "like a big port or migration (the **show-me-your-work** skill)" became "like a big port or migration, and keep the decision trail of such work with `build:work-trace`, which is never committed". The trail is never committed here, so the parenthesis would have sent the agent to commit it.
- `type-system-discipline`: the sentence "Skills like `typescript-best-practices` ground it in specific syntax." is left out, because that skill is not in the devkit. The two references in the form "the **name** principle skill" became links to the sibling files.
- `fix-root-causes`: the bold line "Restart bugs: suspect state before code" became a heading, which markdownlint demands of a line that stands as one. "Reproduce first" became "Reproduce first, end to end, as close to how a user meets the bug as possible", the line of `conventions:engineering` that the workflow design moves here.
- `test-behavior-not-implementation`: added the paragraph "Collaborators" before "Keep": prefer real collaborators and fakes over mocks of your own code, mock only what crosses the process boundary, and a flaky test is a bug that is fixed or deleted, never retried. These are the lines of `conventions:engineering` that the workflow design moves here, with the reason that a mock of your own code asserts how the code is built, where a fake still runs the behavior.

The index, `SKILL.md`:

- Its lines for the 24 principles are adapted from the section "Principles" of upstream's `poteto-mode` skill and from the descriptions of the principle skills. Each line has the form `- **<name>** (<origin>). <When it applies>. <The rule in one sentence>.`, where upstream wrote the title in bold, the skill name in parentheses and one to three sentences.
- Upstream's groups (core, architecture, verification, delegation, meta) are kept, and the group steering is added for the Lyngon principles.
- The lines of `never-block-on-the-human`, `encode-lessons-in-structure`, `outcome-oriented-execution`, `sequence-verifiable-units` and `fix-root-causes` state the patched rule.

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

### `plugins/build/skills/work-trace`

`SKILL.md`:

- Renamed from `show-me-your-work` to `work-trace`, a noun that reads after the plugin's name, as in `/build:work-trace`. The title follows.
- The description: "for long-running or unattended work" became "of long, unattended or multi-phase work", it adds that the helper writes the log, that the log is checked against the transcript and scanned by a reviewer on another model, where it lives, that it is named after the branch and never committed, and that `build:pull-request` posts it with its Attention section, and "autonomous or multi-phase runs" became "long-running, autonomous or multi-phase work". "Use for /show-me-your-work" became "Use for 'show me your work' or 'keep a work trace'", since the slash command has another name here, and "work a human reviews after stepping away" became "work the owner reviews after stepping away". `disable-model-invocation: true` is removed, so that the agent starts the skill on its own trigger, as the workflow design says. Added an `argument-hint`.
- "Columns:" became "The columns:", "ISO8601" "ISO 8601", and "PR number" "pull request number".
- The example is the Markdown table that the helper's `table` prints, where upstream showed the TSV in a fenced block without a language. markdownlint fails a hard tab in a fenced block, and a Lyngon fenced block names its language.
- "Copy `references/decision-log-template.tsv` (the header row) to start a clean log." is left out with the file, since the helper writes the header on first use, so the header has one home. "A bare `printf` appending a row works too, but mind those same bytes if cells come from generated or user-supplied text." is left out too, and "Use the helper" became "Write every row with this skill's helper, from the root of the repository", since the helper is the one place that keeps a cell on one line and away from a formula.
- The helper is `${CLAUDE_SKILL_DIR}/scripts/trace.py append <logfile> ...`, in a fenced block, where upstream ran `scripts/log.sh <logfile> ...` inline. `${CLAUDE_SKILL_DIR}` is a substitution that Claude Code documents for a skill. "strips stray tabs/newlines, and prefixes any cell starting with `=`, `+`, `-`, or `@` with a single quote" became "turns tabs and line breaks inside a cell into spaces, and puts a single quote before any cell starting with `=`, `+`, `-`, or `@`, so that a spreadsheet never runs a cell as a formula", the reason that upstream's script gives in a comment.
- "(the **unslop** skill applies to log text too)" became "(`writing:unslop` applies to log text too)".
- "a gate fixed" became "a check fixed", since a gate is where an agent stops for the owner, and "Log decision points and checkpoints" became "Log decision points and milestones", since `CONCEPTS.md` lists "checkpoint" as a word to avoid.
- "A run is one agent conversation, including its later turns and any summary of it. A pickup, a replacement agent, or a new chat starts a new run." became "A run is one session, including its later turns and any compaction of it. A pickup, a replacement agent, or a new session starts a new run." "its evidence names this run, such as its agent id" became "its evidence names this run by its session ID, `${CLAUDE_SESSION_ID}`", another documented substitution.
- In "Where it lives", upstream kept the log at `decisions.tsv` in the work dir, or `.audit/<task-slug>.tsv` when several efforts run at once, out of git, and committed it "only when the work is ambitious enough that a reviewer needs the trail to trust the result". Here the log is `tmp/work-trace/<branch>.tsv`, "where `<branch>` is the name of the branch the work is on, with each `/` replaced by `-`", "That `tmp/` is the directory at the root of the repository that holds agent scratch, never the system's temporary directory" (the sentence that `build:arena` needed, see there), and it is never committed. "`build:pull-request` posts the log on the pull request of the branch, with its Attention section, as one comment. This skill posts nothing." The workflow design settles all three: the log is named after the branch so that `build:pull-request` finds the log of the change it hands over, and the trail is always posted, since a trail that is never posted goes with the worktree, and the owner reviews on the pull request, not in the reply.
- "(the **encode-lessons-in-structure** principle skill)" became "(the principle `encode-lessons-in-structure`, a file of `principles:index`)".
- "Read this run's transcript under the active workspace's `agent-transcripts/` directory (the system prompt names the path). Don't glob across `~/.cursor/projects/*/`. That reads unrelated private chats." became: read the file `${CLAUDE_SESSION_ID}.jsonl` under `projects/` in the Claude configuration directory, which is `~/.claude` unless `CLAUDE_CONFIG_DIR` names another, "Find it by that name and open no other file there. The others are other sessions, unrelated private conversations." Claude Code documents that path and that variable.
- After the paragraph on the "Attention" section, added "Write the same section to `tmp/work-trace/<branch>.md`, beside the log, for `build:pull-request` to post. The file does not replace the section in the reply. A later run on the same branch writes the file again, for the whole log." A first wording that put the file and the reply in one sentence ended 5 of 5 replies of the eval case `work-trace-logs-and-is-reviewed` without the section, each pointing at the file instead (sonnet, 2026-10-28).
- The heading "Cross-model review of the trail" became "Review of the trail on another model". "spawn a subagent on a different model family from the one that did the work" became "spawn a subagent on a different model than yours that is no weaker, where the harness offers one (the Agent tool's `model`), in the foreground (`run_in_background: false`)". Why "no weaker" is under `plugins/build/skills/arena`, and why the foreground is named under `plugins/discover/skills/how`. Added "Give it the paths of the log and of the transcript", since a subagent sees nothing of the session that started it. "the user" became the owner, twice.
- "GitHub renders a committed TSV as a table. `column -s$'\t' -t decisions.tsv` renders it in a terminal." became "The helper's `table` renders the log for a terminal as well as for a pull request comment.", since the log is never committed.
- Paragraphs are reflowed to one sentence per line, with blank lines around lists. A bullet keeps its sentences on one line.

`scripts/trace.py` is written in Python from upstream's `scripts/log.sh`, as the workflow design says.

- Its command `append` takes upstream's six arguments and keeps upstream's behaviour: the timestamp in UTC, the header on first use, the directory created, a tab, a line feed or a carriage return in a cell turned into a space, and a single quote before a cell that starts with `=`, `+`, `-` or `@`.
- It tells first use by the position of the log opened for appending, where upstream tested the size with `[ -s ]` and then appended, so the test and the write can no longer see two different files. Upstream's comment on a network mount that fails the test goes with the test.
- A cell's bytes that are no UTF-8, as a file name can hold, are written as they came, as upstream writes them, and `table` prints each as the replacement character.
- It reads its arguments by position, so a cell may start with a dash. A wrong number of them exits 2, the status of a usage error, where upstream exits 1.
- Added the command `table`, which prints the log as a Markdown table with `|` escaped, and refuses a missing log, a log without the header and a row of another number of cells.
- It imports the standard library only, and `plugins/build/tests/work-trace.sh` runs it with nothing on the PATH but the tools of the baseline option `lyngon.scriptTools`.

`references/decision-log-template.tsv` is left out, as above.

### `plugins/build/skills/benchmark`

- Renamed from `benchmark-checklist` to `benchmark`, a noun that reads after the plugin's name, as in `/build:benchmark`. The title follows.
- The description adds what the report gives, and "Vet a perf measurement" became "Vet a performance measurement". `disable-model-invocation: true` is removed, so that the agent starts the skill on its own trigger, as the workflow design says and `explain-the-number` sends it here. Added an `argument-hint`.
- "[Explain the Number](../principle-explain-the-number/SKILL.md) says why." became "The principle `explain-the-number`, a file of `principles:index`, says why."
- "the user" became the operator, twice, and "a PR's before and after" "a pull request's before and after".
- "Still check questions 4 and 7" and "could not check questions 4 and 7" name the two questions, "Did it error?" and "Did it even happen?", as the principle `name-things` asks.
- "Keep a PR body to one primary number, per the **Opening a PR** playbook. Put the runs, the range, and the limiter evidence in a linked artifact or a notes file." became "Keep a pull request body to one primary number. Put the runs, the range, and the limiter evidence in a pull request comment that the body points at." The playbook is not in the devkit, and evidence too long for a body goes into a comment, as the workflow design says.
- "Give the number with its unit, the run count, the range, and the limiter." became "Give the number with its unit, which is the median of the runs, the run count, the range, the limiter, and the load average and core count that `uptime` and `nproc` showed before the runs.", and the example ends ", load 0.4 on 8 cores". Without the load, sonnet left out the check of it in 5 of 7 runs of the eval case `benchmark-finds-work-that-never-ran` that ran with the skill, while it followed the rest of the procedure. With the load and without "which is the median of the runs", 1 of 3 replies gave ranges and no median, which question "Does it reproduce?" asks for (2026-10-28).
- The section "How this fits the other perf material" is left out. It places the skill beside the playbooks "Perf issue" and "Hillclimb", which are not in the devkit.
- Paragraphs are reflowed to one sentence per line. A question keeps its sentences on one line.

### `plugins/build/skills/figure-it-out`

- Upstream's description starts "Design an auditable playbook when no narrower one fits", and here "Design how the work will run before running it, when no narrower skill fits", followed by what the skill does. "Use for /figure-it-out, 'figure it out', a large migration, or when no narrower playbook applies." became "Use only when the operator asks for it: 'figure it out', 'figure-it-out'. Not on your own initiative." The workflow design lets the agent start the skill only when the operator asks for it, and a large migration as a trigger would start it, and through it `build:architect` and `build:arena`, on its own. `disable-model-invocation: true` is removed, so that the skill can start when the operator asks for it in words. Added an `argument-hint`.
- "When the task matches no playbook, design one." became "When no narrower skill fits the task, design how the work will run.", and "The deliverable before any code is the workflow itself" "The deliverable before any code is the phase list". "Workflow" is a term of `CONCEPTS.md` for the way of working in a repository, and the devkit has no playbooks.
- The section "Start" and its todo list, whose first item was to read the section "Principles" of `poteto-mode`, are removed. Added the two sentences that say that the principles the skill names are files of `principles:index`, as in `build:architect`. Each "the **name** principle skill" became "the principle `name`".
- Added the paragraph on the design file, as in `build:architect`: the framing and the phase list go into the branch's file under `docs/plans/`, or a new one, committed on the branch and removed by the build plugin when the work is finished. Upstream named no place. "Write the designed phase list down. That list is what the human reviews." became "Write the phase list into the design file. That list is what the owner reviews."
- The headings lose "Phase A:" to "Phase E:", "Design the workflow" became "Design the phases" and "Keep the audit trail" "Keep the trail". The text names a step where upstream named its letter: "the Phase C loop discipline" became "the discipline of "Run the loop"", "the Phase D log" "the trail of "Keep the trail"", and "the Phase A predicate" "the predicate from "Frame"".
- "Present the framing and tradeoffs before committing to a long run. Reversible work proceeds (the **never-block-on-the-human** principle skill), but a multi-hour run earns one checkpoint." became "Write the framing and its trade-offs into the design file before a long run starts. Reversible work proceeds (the principles `never-block-on-the-human` and `review-results-not-plans`)." A checkpoint that the owner did not ask for is a gate that `review-results-not-plans` forbids.
- Added, at the end of "Design the phases", the gate that the owner asks for, "as in "show me the plan first"": commit the design file on the branch and stop with one question, the last sentence of the reply, whether the owner approves the phase list, in the words that `build:architect` needed for its gate. "Otherwise go on without stopping."
- "Decompose into atomic, independently-landable units." became "Decompose into atomic units that each end in a state you can check." A change lands as one pull request, so its units do not land on their own, as the patch to `sequence-verifiable-units` says.
- "For one-way-door design decisions, run the **architect** skill (it runs **arena**)." became "invoke `build:architect`, which runs `build:arena`, then continue here", since a skill invoked in the lead's context takes the session over.
- "Then execute the design. Add its steps to the todolist as concrete items, after the Phase C entry and before Phase D. Run each under the Phase C loop discipline, and weave the Phase D log through them" became "Then run the phase list. Run each step under the discipline of "Run the loop", and weave the trail of "Keep the trail" through them", without the todo list.
- "gate" in the sense of a check became "check": "Rigor is gates and artifacts" became "Rigor is checks and artifacts", "If a worker games the gate" and "If the gate itself is wrong, fix the gate" name the check, and "Encode any recurring correction as a gate, a lint rule, a check, or a script" became "as a check, a lint rule, or a script". A gate is where an agent stops for the owner.
- "Log the run via the **show-me-your-work** skill. figure-it-out's work is usually ambitious enough to commit the trail so the reviewer can read it in the PR." became "Log the run with `build:work-trace`. `build:pull-request` posts the trail on the pull request, where the reviewer reads it to trust the result." The trail is never committed, and `build:pull-request` posts every branch's trail.
- "the human" became the owner in "lets the owner come back and trust the work", "a human can audit" became "the owner can audit", and "work a human reviews after stepping away" in the description "work the owner reviews after stepping away".
- In the reply, "the playbook you designed" became "the phase list you designed", and "the decision-trail path" "the path of the decision trail".
- Paragraphs are reflowed to one sentence per line. A bullet keeps its sentences on one line.

### `plugins/build/skills/clean-comments`

- Renamed from `no-comments` to `clean-comments`, which says what the skill does and reads after the plugin's name, as in `/build:clean-comments`. The title follows.
- Upstream's description is "Spawn Comment Sicko, fix accepted findings, and offer encodings for claimed constraints." It became what the skill does, with the agent's name, and "Use before a change goes to a pull request, and for 'no comments' or 'clean the comments'", since the workflow design has the skill run before every pull request. `disable-model-invocation: true` is removed, so that the agent starts the skill. Added an `argument-hint`.
- "Comment Sicko" became the agent `build:comment-auditor`, and "Comment Sicko's fresh perspective" "the auditor's fresh perspective".
- Added the two sentences that say that the principles the skill names are files of `principles:index`, as in `build:architect`.
- "the current diff against the base branch, default `main`" became "the current diff against the base branch, the default branch unless the branch targets another".
- Each step got a name in bold ("Spawn the auditor", "Vet its report", "Fix the trivial flags", "Fix at the root", "Encode the constraints", "Report"), and "Step 4 implements" became ""Fix at the root" implements", as the principle `name-things` asks.
- "Spawn `Task` with `subagent_type: "Comment Sicko"`." became "Spawn the agent `build:comment-auditor` (the Agent tool's `subagent_type`) in the foreground (`run_in_background: false`)." Why the foreground is named is under `plugins/discover/skills/how`.
- In "Vet its report", "exception-protected deletions" became "deletions that its exceptions protect". "A keep survives only with proof it is about something we cannot change" became "with proof that it is about something we cannot change" and gained "or that it states a reason or an invariant that the code cannot show and no check holds", the exception that the owner added to the agent (see `plugins/build/agents/comment-auditor.md`). "scoped lint and TypeScript suppressions" became "scoped lint and type-checker suppressions", since a Lyngon repository also holds Python. "run `/how` or `/why` on their symbol" became "have a subagent of its own invoke `discover:how` or `discover:why` on their symbol, started in the foreground (`run_in_background: false`)", as in `build:architect`, where either skill invoked in the lead's own context would take the session over. "fail `/no-comments`" became "end this skill as failed".
- "If any fix needs a shape, run `/architect` once for the accepted set and surrounding code. Stop at the sketch. Architect shapes. Step 4 implements." became "invoke `build:architect` once for the accepted set and surrounding code. Stop at its sketch, then continue here: it shapes, and "Fix at the root" implements."
- "The **principle-fix-root-causes** and **principle-redesign-from-first-principles** skills guide intent only." became "The principles `fix-root-causes` and `redesign-from-first-principles` guide intent only."
- "Offer the cheapest in-scope type, runtime, test, or CI lint. Wait for interactive approval. Unattended and eval require caller pre-approval. If approved, encode then delete. Otherwise delete, report the constraint open, and sketch out-of-scope work." became: for every constraint that is not about something we cannot change, encode it as the cheapest in-scope type, runtime check, test, or CI lint, then delete the comment, "and name the encoding in your reply, so that the owner can reject it on the pull request"; "When no encoding fits in scope, delete the comment, report the constraint open, and sketch the out-of-scope work." An approval that the owner did not ask for is a gate that `review-results-not-plans` forbids, and the encoding is reviewed with the rest of the change.
- The report names "encodings" where upstream named "encoding offers, encodings", and "the sketch of `build:architect`" where it named "architect sketch".

### `plugins/build/agents/comment-auditor.md`

- Renamed from `comment-sicko.md`, with the frontmatter name `comment-auditor` where upstream's is `Comment Sicko`, so that Claude Code names the agent `build:comment-auditor` and the name and the file agree, as `validate-marketplace` checks. The title follows.
- The persona is removed, as the workflow design says: the first output "Yes... Ha ha ha... Yes!", the description "A deranged comment-hater that savors deletion and condemns workaround code", the first person and the words "meat", "crawl away", "stink", "scent", "conviction", "confession", "alibi" and "leash". The text addresses the agent as "you", and the description says what the agent does and that `build:clean-comments` spawns it.
- "Feed me the parent scoped files or diff. If none exists, feed me the current diff against `main`." became "Your scope is the files or the diff that the parent gives you, or the current diff against the default branch when it gives none."
- Added the exception "A reason or an invariant of our own code that the code cannot show and no check holds, which the principle `record-what-the-code-cannot-show` admits. When a reshape, a type, or a check could carry it, it goes, with the flag above." The owner chose it in the review of this change. Without it the agent deletes the comments that `record-what-the-code-cannot-show` admits and that `conventions:nix` demands ("Override a baseline value in place, with a comment saying why").
- "I run `/how`, `/why`, or both from the **how** and **why** skills on the named symbol or call" became "have a subagent of your own invoke `discover:how`, `discover:why`, or both on the named symbol or call, started in the foreground (`run_in_background: false`)", for the reason given under `plugins/build/skills/clean-comments`.
- "Only a foreign keep-list gotcha proven true today on a live path crawls away. Our-code surprises die with the reshape flag above. Doubt after the hunt is meat." became "Only an exception from the list, proven true today on a live path, stays. Surprises in our own code go with the flag above. Doubt after the investigation means the comment goes."
- "A long justification without a proven keep-list exception is a confession. Kill it. Never polish meat into a shorter alibi." became "A long justification without a proven exception is an admission that the code is wrong. Delete it, and never shorten it into a briefer excuse." "My kill ends there. I do not touch the code." became "Your part ends there: you do not touch the code."

### `plugins/build/skills/auto`

`SKILL.md`, from every section of `poteto-mode/SKILL.md` but "Principles":

- Renamed from `poteto-mode` to `auto`, a word that reads after the plugin's name, as in `/build:auto`. The title follows.
- The description says what the mode does and that only the operator starts it, where upstream's is "poteto's agent style for concise, detailed responses, deliberate subagents, unslopped prose, simple code, and verified work. Use for poteto, /poteto-mode, or requests to work in this style." `disable-model-invocation: true` stays. Cursor's fields `mode`, `icon`, `color` and `reminder` are removed. Added an `argument-hint`, since the operator starts the mode with the task.
- Added the field `hooks` to the frontmatter, which names the plugin's `hooks/lead-writes-no-code.py` as a `PreToolUse` hook on `Edit`, `Write` and `NotebookEdit`. It refuses the lead of the mode a write of a file of the change, and names the `build:implementer` delegate instead. Upstream's mode has no hooks, and with its text alone the lead wrote the fix itself in 2 of 6 runs of the eval case `bug-fix-repro-first` (sonnet, 2026-10-31). It also names `hooks/reply-has-no-dash.py` as a `Stop` hook, which sends a reply whose prose holds an em dash or an en dash back to the lead once. With the rule in the section "Proof and the reply" alone, the reply of `bug-fix-repro-first` held one in 3 of 6 runs (sonnet, 2026-10-31).
- Added the opening paragraph: the operator switched the mode on for one task, the mode adds routing, delegation and the rules for proof and the reply to the standing instructions, those still hold, and the pull request format is `build:pull-request`'s. The workflow design keeps the gate, the principles and the pull request format out of the mode, since a session without it must still have them.
- Added the paragraph "When you write the summary for a compaction of this session, say in it that the operator started `/build:auto`, and that the session reads this file, `${CLAUDE_SKILL_DIR}/SKILL.md`, again before its next step." A compaction keeps the most recent skills up to its budget, and a session that invoked about 100,000 characters of skills after the mode loses the mode's text. The standing instructions then say to read the file again, and in 0 of 4 runs of the eval case `mode-lost-is-reread` did the resumed agent read the file before it edited or delegated, although a resumed session quoted that sentence and knew that the mode was gone. It followed the summary instead. With this paragraph the summary names the file, and 6 of 6 runs read it before their next step (sonnet, 2026-10-28).
- The section "Non-negotiables" became "Triggers". Its opening, "The Principles section below grounds every trigger. In your reply, name each principle that shaped a decision and the specific choice it changed. Cite only principles whose leaf SKILL.md you read this session.", became "In your reply, name each principle that shaped a decision and the choice it changed. Cite only principles whose file you read this session." "Remaining triggers:" is left out.
- The section "Principles" is left out. It built the index of `plugins/principles/skills/index`, and the standing instructions send the agent there before work that takes judgment.
- The section "Autonomy" is left out. "Just do it", "Always pause" and the session overrides are the gate of the standing instructions, which ask before any message outside GitHub and before spending money, where upstream let "external actions (team chat, ticket updates, kicking off evals) proceed without asking". The overrides ("Don't stop", "going to bed", "run until done") are the triggers of the Autonomous run playbook. Its paragraph "No is an acceptable answer." moved to "Proof and the reply", unchanged but for its reflow.
- "Nontrivial change, architecture decision, or "are we sure?" → the **how** skill." became "have a subagent invoke `discover:how` over the subsystem, in the foreground (`run_in_background: false`). What it returns grounds your work and is never the reply." A skill invoked in the lead's own context takes the session over, as under `plugins/build/skills/architect`.
- The trigger on `AskQuestion` became the subsection "Before you ask". "it is not the human's to answer" names the operator, the reply is "Sketch it per the Prototype playbook", and "If the task is a read-only Investigation whose deliverable is a cited answer, stay in it" became "When the task is a question about the code or its history, answer it from the evidence with `discover:how` or `discover:why`, without a sketch", since the Investigation playbook is not taken. "Under a full-autonomy grant" became "When the operator said not to stop, as in an autonomous run", "with no reply word and no offer" is left out, "Never give a shorthand token to type back" became "never offer a token to type back", and "Gates that the operator named and the Always-pause list in Autonomy still need the operator" became "The calls the standing instructions always ask about still wait for the operator."
- "Code crossing a function boundary → the **architect** skill, parallel design exploration before implementing." names `build:architect`, "which sketches competing designs before the code".
- "Parallel fan-out → the **swarm** skill ... Use **arena** for design or code bakeoffs with base selection and grafting." kept the bakeoff as a trigger of `build:arena`. `swarm` is not in the devkit.
- "Contested design → the **interrogate** skill (multi-model adversarial) before shipping." became "A contested design or a large blast radius: `build:review` before the change is handed over", the condition that the workflow design gives for that skill.
- "Nontrivial multi-step → write the throughput checkpoint (Feature step 3)." is left out of the triggers, and the checkpoint is part of the Feature playbook.
- "Any prose surface → the **unslop** skill. ... Agent-facing prose also follows the **create-skill** skill" became "Any prose, the reply included: `writing:unslop`". `create-skill` is Cursor's own. "Docs, RFCs, readmes, PR descriptions, or commit messages → the **technical-writing** skill" became "Documents, pull request text and commit messages: `writing:technical` first", in the order that `opening-a-pr.md` gives the two.
- "Before commit → the `deslop` skill" and "Before review → the **no-comments** skill" are left out. `deslop` is not in the devkit, and `build:pull-request` runs `build:clean-comments`.
- "Shipping UI / IDE / CLI → the matching control skill. ... For bug fixes, reproduce first on the same surface yourself." became "A bug in a UI, a CLI or a service: reproduce it yourself on the same surface before anything else." The control skills are not in the devkit, and the exception they point at is in the Bug fix playbook.
- The triggers for Babysit, Shipping and the comments of Bugbot are left out, with their playbooks and `references/bugbot-triage.md`, which are on the shelf.
- "Broken skill mid-task → fix it in its own PR. Don't block. Don't silently work around it." became "fix it in a change of its own, per the principle `fix-debt-in-its-own-change`. Do not block on it, and do not work around it silently."
- "Long, autonomous, or multi-phase work ... → a decision trail via the **show-me-your-work** skill. Commit it when stakes need an auditable record. Keep it local otherwise." became "`build:work-trace` from the start", with the examples of upstream's trigger in words. The trail is never committed, and `build:pull-request` posts it.
- Added "A bug with a cheap local test path: `build:tdd`" and "Running a benchmark, or reporting a speedup or regression you measured: `build:benchmark`", the triggers of the two skills, where upstream reaches `tdd` only from the Bug fix playbook and names `benchmark-checklist`.
- The section "Subagents": "Use `subagent_type: "poteto-agent"` for any subagent you spawn inside a playbook step" became "A delegate that writes code is the `build:implementer` agent", whose brief names the files, the data shape and its organizing structure, what must hold and the proof owed (upstream's step 4 of the Feature playbook), and the path of the mode's file, `${CLAUDE_SKILL_DIR}/SKILL.md`, which the delegate reads in full. A flagged skill cannot be preloaded into a subagent, and upstream's agent reads the mode by name. "`/poteto-mode` and `poteto-agent` route through the same wrapper." is left out. "Routed workflow skills ... set their own `subagent_type` for diverse-model review. Respect what the skill prescribes" became "A skill this mode routes to starts its own subagents and picks their models; leave that to it."
- "Defaults for every `Task` call." lost `run_in_background: true`, which became the foreground, named with its parameter as under `plugins/discover/skills/how`, and "agent mode (readonly strips MCP)", which is Cursor's. "file pointers not inlined context" became "Give file pointers, not pasted context." The model for each role, its defaults, the names of the models and the rule of `/setup-pstack` are left out. The tiers stay: "The hardest changes ... go to the strongest model the harness offers", and "A trivial mechanical edit may go to a faster model". "A second opinion is the same prompt against a different model" gained "than the one that did the work, where the harness offers one". "You own every subagent's work" became "You own every delegate's work".
- In "Fresh subagents by default", "Resume, message, or queue a follow-up on an existing subagent only when" became "Send a message to a subagent that already ran only when", and its examples "its local checkout, its uncommitted changes, or a process it still runs, such as a dev server, a simulator, or a babysit watcher" became "such as uncommitted changes or a process it still runs". "A role such as a PR owner outlives its agent. ..." is left out, since no playbook taken has such a role. "Interrupt-chained resumes silently drop directives, so fire a fresh subagent with consolidated scope rather than trusting a "done" summary." became "A chain of resumed agents drops directives silently, and a "done" summary is a claim, not proof."
- The section "Writing the reply" became "Proof and the reply". "No long-dash character anywhere" became "No em dash and no en dash", with the examples "`main.py` owns persistence" and "End to end through the CLI", where upstream wrote "`main.js` owns persistence and the IPC handlers" and "End to end via CDP". "(unslop rule 14)" is left out, since the devkit's `writing:unslop` numbers its rules otherwise. "Frame impact for the consumer and the maintainer." became the label "Impact first.", and "Never fabricate a link, citation, or transcript reference." became "No invented links. Link, cite or quote only what you produced or read this session." "Never hand the human a check you could run." became a bullet of its own, "Run the check yourself."
- "Every playbook ends with a reply written this way, PR link as `https://github.com/<owner>/<repo>/pull/<number>`." became "with the link of the pull request that `build:pull-request` opened".
- The section "Comments" names the principles `reshape-instead-of-commenting` and `record-what-the-code-cannot-show` for the comment that stays, and its examples are Python (`# Phase 1: add cards`, `assert saved, "persisted across restart"`), where upstream's are JavaScript.
- The section "Playbooks": "Open a todolist whose first items are the matched playbook's steps, copied in verbatim, ..." became "Match the task to one playbook, read its file next to this one, and hold the work to what it says must hold and to the proof it owes." The index holds the five playbooks taken, and the other eighteen are left out. "Use **figure-it-out** whenever no bundled playbook fits. It designs a bespoke, rigorous playbook for the task." became "So does ... a task that fits no playbook. That skill designs a run for the one task." The sentences on Orchestrate are left out. The Refactoring line says "deduplicate" for "dedupe", and the Autonomous run line has the triggers "run until done", "don't stop" and "going to bed", where upstream's "/loop until X" is Cursor's.
- Paragraphs are reflowed to one sentence per line.

The playbooks, common to all five:

- Each is a file with a heading of the first level, where upstream's start with a heading of the third, and its bold opening became plain sentences.
- Every numbered step is restated as what must hold when the task is done, under "What must hold", and what proof is owed, under "Proof owed", as the principle `prescribe-proof-not-steps` demands and the workflow design asks of each playbook. A step stays an instruction only where it is a fact that the reader cannot derive.
- A principle is named as in "the principle `model-the-domain`", where upstream wrote "**principle-model-the-domain**" or "the **name** principle skill".
- "the user" and "the human" became the operator.
- A delegate that writes code is a `build:implementer` delegate, where upstream named "a subagent using your configured feature model (default `grok-4.7-xhigh-fast`)" and its like in the other playbooks.
- A step that ran the **how** skill became a subagent that invoked `discover:how`, as in `SKILL.md`.
- Upstream's last step, "Run **Opening a PR**", became "Then invoke `build:pull-request`."

`playbooks/feature.md`:

- "`architect` for parallel design exploration" became "A design that crosses a function boundary was explored through `build:architect` before the code", the trigger of `SKILL.md`, where upstream ran the skill on every feature.
- The throughput checkpoint is "written, one line per dimension", where upstream wrote it "as four todo items", and "keeps its item with `n/a: <reason>`" became "keeps its line as `n/a: <reason>`".
- From step 4: "Mandatory: no skip-with-reason escape, and Laziness Protocol does not override it" became "No reason to skip the delegate counts, the principle `laziness-protocol` included". "No "standing by" reply that waits on a nested agent." is left out, since every subagent starts in the foreground. "Comments per **Comments**." is left out, since the section of `SKILL.md` holds for every file. "Commit liberally." is left out, since the standing instructions say to commit as you go.
- "Verify on the matching surface." became the proof "The feature verified on the surface where it is used: the CLI run, the page driven, the endpoint called."
- "Rebase into small, ordered commits. Stack follow-ups." became "Commits in the order that proves the work, per the principle `sequence-verifiable-units`". A change lands as one squash commit, so its commits are not rebased into future pull requests, and a follow-up is a change of its own.
- "If the design is contested, `interrogate` before shipping." became "A contested design went through `build:review` before the hand-over."
- "Spawn a fresh owner rather than chaining interrupts." became "give each phase a fresh owner rather than a chain of resumed ones".

`playbooks/refactoring.md`:

- "API reshapes" became "An interface that changed shape", and "Spot-check every rename against the actual files. Renames silently miss usages in strings, prose, and back-references." became "Every rename was checked against the files. A rename misses uses in strings, in prose and in back-references without any error."
- "a smoke run on the matching surface via the relevant control skill" became "a run on the surface where the code is used".
- "Rebase into small ordered commits." became "Commits that tell the story", for the reason given under `playbooks/feature.md`.

`playbooks/bug-fix.md`:

- "Reproduce it yourself on the matching surface via the control skill (Non-negotiables)" became "You reproduced the bug yourself, on the surface where it was reported".
- "Binary-search the cause." became "The cause was found by elimination." "Seed them with `how` over the affected subsystem and the **why** skill for regression history" became subagents that invoked `discover:how` and `discover:why`. "Drive a long or stubborn hunt with Cursor's `/loop` command." is left out. "Confirm the surviving *mechanism* with runtime evidence before the step-3 architect/interrogate fan-out." became "The surviving mechanism was confirmed by runtime evidence before the fix was designed."
- "Delegate implementation to a subagent using your configured bug-fix model (default `grok-4.7-xhigh-fast`) with a specific scope." became "A `build:implementer` delegate wrote the fix and its test, with a specific scope, however small the fix is. No reason to skip the delegate counts, because the gain is the separation of writing from review, not lines saved.", in the words of the Feature playbook's mandate. Without them the lead of the eval case `bug-fix-repro-first` wrote a one-line fix itself, judging a delegate to be process without gain (sonnet, 2026-10-28), where upstream's opening says to delegate the fix and stay the lead.
- "See the **tdd** skill for the failing-test-first cadence when the bug has a cheap local test path. Skip it when the test would be expensive, integration-heavy, or unclear." became "When the bug has a cheap local test path, the reproduction is a test written per `build:tdd`, and it stays as a regression test. When the test would be expensive, heavy on integration or unclear, the closest executable check takes its place." Keeping the reproduction as a regression test is the line of `conventions:engineering` that the workflow design gives to `build:tdd`.

`playbooks/prototype.md`:

- "Build throwaway in an isolated scratch dir, separate from production source." became "The prototype lives in `tmp/prototype/<slug>/`, in the directory `tmp/` at the root of the repository, apart from the production source", in the words that `build:arena` needed for `tmp/`. "CDN deps, a dev server with hot reload" became "dependencies from a CDN and a server that reloads".
- "screenshot each variant via the control skill" became "a screenshot of each variant".
- "Hand the chosen direction to **Feature** (or `architect` for the shape) for the real build." became two endings. An empirical fork is settled by the observation, and the work carries on under the Feature playbook or through `build:architect`, which ends with `build:pull-request`. A visual or preference decision is the operator's, so the reply presents the variants, the trade-offs and a recommendation, and stops with one question, as the standing instructions ask for a preference call that no run can settle.

`playbooks/autonomous-run.md`:

- "all N PRs merged" became "every pull request of a list opened", since the owner decides every merge.
- "Pick the wake mechanism using Cursor's `/loop` command (a built-in, not a pstack skill)." became "The run wakes itself." The watcher is "a watcher", where upstream wrote "a watcher subagent".
- "Address ... yourself via poteto-mode. Put out-of-band fixes in their own PR." became "Each fix outside the task went into a change of its own, per the principle `fix-debt-in-its-own-change`." "Do not park reversible work for the human or use `AskQuestion`." became "No reversible work was parked for the operator, and no question was asked about it." "Surface only irreversible actions, genuine product or preference calls no experiment can settle, or a real dead end." names "an action the standing instructions always ask about" for the irreversible action.
- "Checkpoint every iteration via the **show-me-your-work** skill" became "Every iteration has its row in the trail of `build:work-trace`".
- Added "Then invoke `build:pull-request`", as every playbook ends.

### `plugins/build/skills/pull-request`

Made a skill from the playbook `opening-a-pr.md`, so that the agent hands a change over without the mode, as the workflow design says.

- Named `pull-request`, a noun that reads after the plugin's name, as in `/build:pull-request`. Added a frontmatter: a description of what must hold and when to use it, with the triggers "open the pull request", "hand it over" and "ship this branch", and an `argument-hint`.
- "Invoked at the end of every other playbook." became the opening on the change as one pull request that lands as one squash commit, whose title and body describe the whole change.
- The paragraph "Worktree" is left out. The workflow design mandates no worktree, and its `git fetch && git reset --hard origin/<branch>` and "Snarled worktree: reset from main, redo minimally" can discard work.
- The paragraph "Commits" is left out. The standing instructions say to commit as you go and that branch commits are free-form, and "Rebase into small, ordered commits before opening PRs. Each commit is a future PR" contradicts a change that lands as one commit.
- In "PRs", `/deslop` is left out, since it is not in the devkit, and "Run `/no-comments` before review" became the first thing that must hold, "`build:clean-comments` ran over the diff of the change". "Write every PR title, PR description, and commit body with `/technical-writing`, then apply `/unslop`. Apply every technical-writing layer except Diátaxis." became "Write it, and the title, with `writing:technical`, every layer but Diátaxis, then apply `writing:unslop`." "Use one word for each action, keep articles, and avoid `-ing` when a plain verb works." is left out, since `writing:technical` states its own rules.
- "Titles": the list of types and the example scopes `pstack` and `poteto-mode` are left out, since `check-pull-request` checks the title with commitizen. Added "A breaking change has `!` before the colon", the mark that the devkit's README names for a breaking change.
- "Descriptions": the paragraph on the briefing stays. "If the body would make the squash commit longer than about 40 lines, cut the body." became `check-pull-request`'s target and limit, which the skill states no number of, since a skill cannot read the options of the baseline. Upstream's six sections, of which one dropped when it had nothing to say, became the seven headings of the workflow design, always present, with "None" written out: "Tradeoffs" folded into "Decisions", and "Verification" became "Verified" and "Not verified". "If main is red, state the cost of leaving it red." is left out. The rule for a performance change ("one primary number with its unit in `before → after` form") is left out, since `build:benchmark` gives the number. "Link the arena or swarm directory for the remaining evidence." and "attach videos or screenshots when they prove a claim" became "Evidence too long for the body goes into a comment on the pull request, which Verified points at." "Do not list SHAs or rebase genealogy" stays as "no SHAs and no history of rebases". "A commit body does not restate its subject." is left out.
- Added the paragraph on a problem met on the way, from the devkit's former `build:finish`: with only a definition of the line `Met on the way:`, 3 of 3 runs of its eval case called a skipped test that names a bug "pre-existing, unrelated" and wrote `Met on the way: nothing.`, and with the paragraph 6 of 6 filed it (pull request 71, 2026-10-14).
- "Forge": Origin and Graphite are left out. The forge is reached through its own command, `gh` for GitHub, as the cases of the skill run it.
- "Built-in PR tool" is left out, since Claude Code has none.
- "Size and stacks": "Prefer five narrow PRs to one large PR." is left out, since the standing instructions make a change one concern. "Each child branch rebases onto its parent's exact tip" became "When the parent gets fixes from its review, merge the parent into the child; nothing is force-pushed", as the workflow design says. The commands of Origin are left out.
- "Readiness": "Open every PR ready, never as a draft" became the line "The pull request is open and ready, not a draft, and you report its link". The flags of Origin and the built-in tool are left out.
- "Babysit": "Opening a PR does not start a babysit. Post the URL and keep building." became "Opening the pull request does not start a watch over it. Report the link and go on with the work." The paragraph on a subagent that opens a pull request is left out, since `build:implementer` never opens one.
- Added from the workflow design: the full check on the pushed head, `check-pull-request` with the command that runs it and the rule never to change its options to pass, the body true again after every push, no line that names the tool or the agent that wrote it, the comment with the branch's work trace and its Attention section, the link in a mistake ledger file written before the pull request, and what to do without a remote, without a forge tool, with a pull request that exists and with a rejected push.

### `plugins/build/skills/tdd`

- The description says what the skill does and when, where upstream's is only when: "Use only when the user explicitly asks for TDD, a failing test, or a regression test, OR when the bug has an obvious cheap local test target" became "Use when fixing a bug that a nearby unit, component or integration test can reach cheaply, and when the operator asks for TDD, a failing test or a regression test", and "and not for new behavior" is added. `disable-model-invocation: true` is removed, so that the agent starts the skill on its own trigger, as the workflow design says. Added an `argument-hint`.
- The title "TDD Bug Fix" and the headings "If a Failing Test Is Impractical" and "Final Response" are in sentence case.
- Step 3 gained "per the principle `test-behavior-not-implementation`".
- Added step 5, "**Commit the failing test.** It lands before the fix, so the history shows it failing first.", the order that the Bug fix playbook demands. The steps after it are renumbered.
- The last step gained "It stays in the suite as a regression test.", the line of `conventions:engineering` that the workflow design gives to this skill. For the same reason "or would be deleted immediately after proving the fix" is left out of what makes a test bad.
- "codepath" became "code path", and the list of regression checks gained its articles.
- Paragraphs are reflowed to one sentence per line.

### `plugins/build/agents/implementer.md`

- Renamed from `poteto-agent.md`, with the frontmatter name `implementer`. The description says what the agent does and that the lead of `build:auto` spawns it, where upstream's says that it is the routing target of `/poteto-mode`. `is_background: true`, a field of Cursor, is removed, since the lead starts every subagent in the foreground.
- "You are operating as poteto-mode's full agent style. Read the `poteto-mode` skill's `SKILL.md` in full before doing any work, including its inline Principles index." became "Before any work, read the mode's file in full, at the path your brief names." The mode's skill cannot be preloaded into a subagent and the Skill tool refuses it, which the added sentence "Starting the mode with the Skill tool fails, since only the operator can start it, so read the file." says. "Navigate to a leaf `principle-*` skill whenever you apply that principle." is left out, since the standing instructions send the agent to `principles:index`.
- Added the reading of the standing instructions, by their place in the plugin, since the mode points at them for what it does not hold.
- Added, from the workflow design, what must hold when the delegate returns, that it neither pushes nor opens a pull request, and its report with the proof.
- "Report only. Name touched files, deletion count, `MUST KILL` flags with one line each, and skips." became "Your reply is the report only: the files you touched, the number of comments you deleted, each `MUST KILL` flag in one line, and what you skipped."
- Every "kill" of a comment became "delete", and "survive", "die" and "crawl away" became "stay" or "go": "Surprises in our own code are meat. Kill them and mark the exact symbol `MUST KILL` for rename, extract, type, or rearchitecture" became "Surprises in our own code go. Delete them and mark the exact symbol `MUST KILL` for the rename, extraction, type, or rearchitecture", "Lint suppressions survive only when" "Lint suppressions stay only when", "kill the suppression" "delete the suppression", "commented-out corpses" "commented-out code", "I want them all." "all of them go.", and "When I am not sure a keep clause applies, the comment dies." "When you are not sure an exception applies, the comment goes."
- Paragraphs are reflowed to one sentence per line. A bullet keeps its sentences on one line. The flag `MUST KILL` keeps upstream's words.

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
- Quality: every upstream description says when the principle applies. Upstream sets `disable-model-invocation: true` on each and reaches them through the inline index of its mode skill; here the index is the skill and the agent may invoke it. Trigger check: "refactor the parser so that adding a format is one file" must trigger the index, "what does this function return?" must not. Bodies are 11 to 36 lines. Three files point at other skills: `explain-the-number` and `prove-it-works` at `benchmark-checklist` and `show-me-your-work`, which are `build:benchmark` and `build:work-trace` here, and `type-system-discipline` at `typescript-best-practices`, which is not in the devkit and whose pointer is left out.
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

### `plugins/build/skills/work-trace`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-28, all 3 upstream files read in full.
Read by Anders Åström on 2026-10-28.

- Security: Network: none. Execution surface: upstream's `scripts/log.sh` appends to whatever path it is given and creates its directory; here `scripts/trace.py` does the same, from the root of the repository. No hooks and no `allowed-tools`. Credentials: the audit reads the run's transcript, which in Claude Code lies in the Claude configuration directory that the checklist names. The patched text reads one file, named by the session's ID, and opens no other file there, which keeps upstream's warning against reading other sessions. The transcript holds whatever the session read, credentials included if it read any, and the reviewer subagent reads it too, on the same machine. Instruction hijacking: none in the text. The transcript and the evidence hold text from anyone, which the reviewer reads, and the helper's quote keeps a cell from running as a formula in a spreadsheet. No encoded content. Persistence: upstream's log in the work dir or `.audit/` (patched to `tmp/work-trace/`, which a Lyngon repository ignores).
- Quality: the description states what and when. Trigger check: "run the migration tonight and keep a trail I can check in the morning" must trigger it, "rename this function" must not. `SKILL.md` is 82 lines upstream with the helper and a one-line template. Dependencies: Python for the helper, which the baseline provides through `lyngon.scriptTools`, and a harness that spawns a subagent on another model. In an eval run the sandbox refuses the read of the transcript, and the skill logs the audit as `INCONCLUSIVE` there.
- Fit: reads no glossary and no decision record. Assumes no layout. Installs nothing. No em or en dashes and no curly quotes upstream. Writes nothing that it commits. Its example was a TSV block with hard tabs, which markdownlint fails (patched). No line carries a term that `scripts/validate-shipped-text.py` lists. Overlap: the execution ledger of `build:execute` and `build:delegate` tracks the tasks of a plan, and this log records decisions with evidence. Both stay until the workflow piece removes the ledger.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/build/skills/benchmark`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-28, the one upstream file read in full.
Read by Anders Åström on 2026-10-28.

- Security: Network: none of its own; a measurement it vets may reach a server. Credentials: none read. Execution surface: no scripts, hooks or `allowed-tools`. It has the agent run `uptime`, `nproc`, `top`, `pidstat`, profilers and `strace -c` under the session's own permissions, and some of them need privileges. Instruction hijacking: none. No encoded content, no persistence.
- Quality: the description states what and when. Trigger check: "measure whether the new parser is faster than the old one" must trigger it, "add a timeout to the HTTP client" must not. `SKILL.md` is 39 lines and has no references, since every measurement needs all of it. Dependencies: the tools above, which a repository declares in `devenv.nix` when it needs them, as every tool.
- Fit: reads no glossary and no decision record. Assumes no layout. Installs nothing, and names tools that may be missing from a repository's environment, where the standing rule of the environment applies. No em or en dashes and no curly quotes upstream, and one character outside ASCII, the arrow of the example. It pointed at three playbooks that are not in the devkit (patched). No line carries a term that `scripts/validate-shipped-text.py` lists. Writes no file of its own. Overlap: `explain-the-number` says why a measured number needs vetting, and this skill is the procedure for a performance number.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/build/skills/figure-it-out`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-28, the one upstream file read in full.
Read by Anders Åström on 2026-10-28.

- Security: Network: none. Credentials: none read. Execution surface: no scripts, hooks or `allowed-tools`. The skill writes code on purpose, since it runs the work it designed, and through `build:architect` and `build:arena` it starts subagents that write; workers that fan out get a worktree or a branch each. Instruction hijacking: upstream proceeds on reversible work without asking, which is the behaviour `never-block-on-the-human` asks for and hides nothing, and its checkpoint for a long run is patched to the gate the owner asks for. No encoded content. Persistence: nothing outside the repository.
- Quality: the description states what and when. Trigger check: "figure it out: move every service off the old config loader" must trigger it, the same migration asked without "figure it out" must not, which the eval case `mode-only-on-request` covers for a plain task. Upstream's "a large migration" as a trigger would start the skill, and several subagents with it, on the agent's own reading (patched). `SKILL.md` is 53 lines and has no references. Dependencies: `build:architect`, `build:arena`, `build:work-trace` and eight principles of `principles:index`, all in the bundle.
- Fit: reads no glossary of its own. Assumes no layout. Installs nothing. No em or en dashes and no curly quotes upstream, and no character outside ASCII. Its words "playbook" and "workflow" collide with `CONCEPTS.md`, its checkpoint with `review-results-not-plans`, and its "independently-landable units" with one pull request per change (all patched). It named no place for the phase list, and here it is the design file under `docs/plans/` (patched). No line carries a term that `scripts/validate-shipped-text.py` lists. Overlap: `discover:approach`, `build:plan` and the executors settle a design with the owner, turn it into tasks and run them. This skill designs and runs ambitious work in one pass, with experiments and a trail. Both stay until the workflow piece decides otherwise.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/build/skills/clean-comments`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-28, the one upstream file read in full.
Read by Anders Åström on 2026-10-28.

- Security: Network: none. Credentials: none read. Execution surface: no scripts, hooks or `allowed-tools`. The skill changes code on purpose, through the agent's deletions and its own fixes and encodings. Instruction hijacking: the comments it reads are text from whoever wrote them, and a comment could address an agent. Upstream already treats "IMPORTANT" and "do not remove" as a lead to investigate, never as proof. Upstream waited for interactive approval of an encoding and required "caller pre-approval" when unattended (patched to the encoding named in the reply). No encoded content, no persistence.
- Quality: upstream's description says what and not when (patched). Trigger check: "clean the comments out of this branch before the pull request" must trigger it, "add a docstring to `parse_rates`" must not. `SKILL.md` is 24 lines and has no references. Dependencies: the agent `build:comment-auditor`, `build:architect`, `discover:how`, `discover:why` and two principles of `principles:index`, all in the bundle.
- Fit: reads no glossary and no decision record of its own. Assumes no layout. Installs nothing. No em or en dashes and no curly quotes upstream, and no character outside ASCII. It named Cursor's `Task` and the base branch `main` (patched). No line carries a term that `scripts/validate-shipped-text.py` lists. Writes no `AGENTS.md`, `CLAUDE.md` or file under `.claude/`. Overlap: `reshape-instead-of-commenting` and `record-what-the-code-cannot-show` say which comment may be written, and this skill checks a change against them afterwards. Its exceptions disagreed with the second (patched in the agent, see there).
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/build/agents/comment-auditor.md`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-28, the one upstream file read in full.
Read by Anders Åström on 2026-10-28.

- Security: Network: none. Credentials: none read. Execution surface: no `tools` list, so the agent has the tools of a general subagent, and nothing but its text keeps it to deleting comments and away from application code. The skill that spawns it rejects a report whose diff edits code. Instruction hijacking: the persona's fixed first output is harmless and removed with the persona. The comments it reads are text from anyone, as for `build:clean-comments`. No encoded content, no persistence.
- Quality: upstream's description is the persona and says nothing of what the agent does (patched). It is spawned by `build:clean-comments` and named by no trigger of its own. 32 lines. Dependencies: `discover:how` and `discover:why`.
- Fit: no em or en dashes and no curly quotes upstream, and no character outside ASCII. The base branch `main` (patched). Its list of exceptions deleted a reason or an invariant of our own code that the code cannot show, which `record-what-the-code-cannot-show` admits and `conventions:nix` demands; the owner chose to add that exception in the review of this change (patched). No line carries a term that `scripts/validate-shipped-text.py` lists. Overlap: none.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/build/skills/auto`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-28: `poteto-mode/SKILL.md` and the five playbooks `feature.md`, `refactoring.md`, `bug-fix.md`, `prototype.md` and `autonomous-run.md`, read in full.
Read by Anders Åström on 2026-10-28.

- Security: Network: none fetched by the text. The Prototype playbook builds a throwaway page with dependencies from a CDN, which a browser fetches when the operator or the agent opens it. Credentials: none read. Execution surface: no scripts, hooks or `allowed-tools` in what was taken; the scripts under `poteto-mode/scripts/` (`watch-pr`, `orch`, `check-plan.mjs`, `bootstrap.ts`, `worktree-audit.sh`) are not taken. Upstream starts every subagent with `run_in_background: true`, which loses a subagent's result in Claude Code (issue 33, patched to the foreground). Instruction hijacking: the section "Autonomy" lets "external actions (team chat, ticket updates, kicking off evals) proceed without asking", which skips confirmations that the standing instructions require (patched, the section is left out for the gate of the standing instructions). No encoded content. Persistence: none.
- Quality: upstream's description is a style ("poteto's agent style ...") and its trigger the author's name (patched). The skill is flagged, so its description serves the operator's menu of slash commands; trigger check: "/build:auto add a --json option to the rate command" must start it, and "add a --json option to the rate command" without the command must not, which the flag ensures. `SKILL.md` is 147 lines and 20,563 bytes upstream, above the 15,000 characters that the workflow design allows the mode; without the section "Principles" and the triggers for skills the devkit lacks it is 8,605. Dependencies: upstream names `swarm`, `deslop`, `create-skill`, `control-cli`, `control-ui`, `babysit`, `reflect`, `setup-pstack`, Cursor's `/loop`, `AskQuestion` and a todo list, none of which is in the devkit or Claude Code (left out). The playbooks it indexes are 23, and 18 are on the shelf (left out of the index).
- Fit: names no glossary; "the human" and "the user" name the operator (patched). Assumes no layout. Installs nothing. No em or en dashes and no curly quotes upstream. Upstream commits the trail of `show-me-your-work` "when stakes need an auditable record", where the trail is never committed (patched). Upstream's "Rebase into small, ordered commits" in two playbooks contradicts a change that lands as one squash commit (patched). No line carries a term of the structure that `scripts/validate-shipped-text.py` lists. Overlap: the plans, the review gates and the executors of superpowers (`build:plan`, `build:delegate`, `build:execute`, `build:finish`), which the change that adds this skill removes.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/build/skills/pull-request`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-28, `poteto-mode/playbooks/opening-a-pr.md` read in full.
Read by Anders Åström on 2026-10-28.

- Security: Network: the skill pushes and opens a pull request on the forge, which is its purpose. Credentials: none read; the forge's command uses its own sign-in. Execution surface: the paragraph "Worktree" runs `git fetch && git reset --hard origin/<branch>` and resets a "snarled" worktree from main, either of which discards uncommitted work (patched, left out). Instruction hijacking: none. No encoded content. Persistence: none outside the repository and the forge.
- Quality: a playbook has no description (patched, a frontmatter added). Trigger check: "the change is done and the full check passes, open the pull request" must trigger it, "commit what we have on the branch" must not. 36 lines upstream. Dependencies: upstream names `/deslop`, Origin, Graphite and a built-in PR tool (left out), and `/no-comments`, `/technical-writing` and `/unslop`, which are `build:clean-comments`, `writing:technical` and `writing:unslop` here. The forge's command, `gh` for GitHub, and `check-pull-request` from the baseline.
- Fit: upstream's body has six sections, of which one drops when empty, and a limit of about 40 lines, where the devkit's `check-pull-request` demands seven headings in order and a length from the baseline (patched). Upstream rebases a branch into commits that each become a pull request, where a change lands as one squash commit (patched). No em or en dashes and no curly quotes upstream; one arrow, `→`, in an example that is left out. Overlap: `build:finish`, which the change that adds this skill removes, and whose paragraph on a problem met on the way it keeps.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/build/skills/tdd`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-28, the one upstream file read in full.
Read by Anders Åström on 2026-10-28.

- Security: Network: none. Credentials: none read. Execution surface: none beyond running the repository's tests. Instruction hijacking: none. No encoded content, no persistence.
- Quality: the description says when and not what (patched). Trigger check: "fix the crash when the quantity is negative; the pricing tests are next to the code" must trigger it, "add a discount field to the order" must not. Upstream flags the skill, so the agent could never start it, where the workflow design has the agent start it on its own trigger (patched). 42 lines. Dependencies: none.
- Fit: no em or en dashes and no curly quotes upstream. "would be deleted immediately after proving the fix" counts a test that is not kept as bad, where `conventions:engineering` keeps the reproduction as a regression test (patched, the test stays). Overlap: `practice:tdd` of superpowers, whose rule "no production code without a failing test" the roadmap replaces with this skill, and which the change that adds this skill removes.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.

### `plugins/build/agents/implementer.md`

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-28, `pstack/agents/poteto-agent.md` read in full.
Read by Anders Åström on 2026-10-28.

- Security: Network: none. Credentials: none read. Execution surface: no `tools` list, so the agent has the tools of a general subagent, as a delegate that writes code needs. `is_background: true` would start it in the background (patched, removed). Instruction hijacking: none. No encoded content, no persistence.
- Quality: the description says that the agent is a routing target and that substituting another drifts, not what it does (patched). It is spawned by the lead of `build:auto` and named by no trigger of its own. 9 lines upstream. Dependencies: the mode's file and the standing instructions, read by path.
- Fit: no em or en dashes and no curly quotes upstream. It reads `poteto-mode` by its name and the leaf skills of the principles, which have other names here (patched). Overlap: the implementer prompt of `build:delegate`, which the change that adds this agent removes.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.
