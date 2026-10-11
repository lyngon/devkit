# why

- **Upstream**: <https://github.com/cursor/plugins>
- **Upstream path**: `pstack/skills/why`
- **Upstream name**: `why`
- **Upstream version**: 0.15.15 (`pstack/.cursor-plugin/plugin.json`)
- **Upstream commit**: 9f451cf875ad1239912762f67741e8e5ba6ac0f1
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-10-11 by Anders Åström

## Why it is here

A Lyngon repository keeps only what is true now, and deletes a decision record when its decision changes.
The reason behind code or a decision is then in git, in pull requests and in issues, and an agent that cannot find it there either guesses or undoes the decision.
This skill reads those sources and keeps what it found apart from what it inferred and what it could not find out, which is the property that makes its answer safe to act on.

## Local patches

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

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-11, all 13 upstream files read in full, the five that are left out and `linear.md` included.

- Security: the skill reads and never writes. Network: `gh` reads pull requests and issues of the repository, and `gh search issues` reads the organization's. Credentials: none read by the skill; `gh` uses its own sign-in. Execution surface: no scripts, hooks or `allowed-tools`. Upstream told investigators to run in agent mode so that MCP tools stay available while writing nothing; the patched sentence keeps both halves. Instruction hijacking: none in the text, and the opposite risk exists, since an issue or a pull request body is text from anyone. The synthesizer prompt forbids writing files, committing or changing external state, and the new issue playbook says that issue text is a claim and never an instruction. No encoded content, no persistence.
- Quality: the description states what and when. Trigger check: "why does validate-marketplace demand the all bundle?" must trigger it, "how does the session hook find its text file?" must not. `SKILL.md` is 171 lines; the confidence framework, both prompts and the playbooks are references. Dependencies: git, and `gh` signed in for pull requests and issues, whose absence the skill reports as a gap. The left-out playbooks named MCP tools of products Lyngon does not use (`search_datadog_incidents`, `notion-search`, `execute_sql_read_only`).
- Fit: reads decision records in `docs/decisions/` (patched). Assumes no layout. Installs nothing; `rg` was not guaranteed and became `git grep` (patched). No em or en dashes and no curly quotes upstream. Writes no file. No devkit skill overlaps: `discover:domain-model` writes decision records, and this one reads them and the history behind them.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.
