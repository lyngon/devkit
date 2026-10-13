---
name: why
description: Investigate why code, a design or a decision is the way it is, and return a cited answer that separates what was found from what is inferred and what is unknown. Reads the decision records, git history, pull request bodies and reviews, and issues, and any other evidence source the session offers. Use for 'why does X work this way', 'why we picked Y', design rationale, regressions, postmortems, or data-backed thresholds, and before changing code whose reason is not visible. For how the code behaves at runtime, use discover:how.
argument-hint: "<the question, naming the code, design or decision it is about>"
---

# Why

Investigate the motivation and intent behind code.

Companion to `discover:how`.
`discover:how` answers what the code does and how it works.
This skill answers what forces led to its shape.

## Operating posture

Operate as a **careful, cautious, and precise investigator**.
Be honest about what you know vs what you're inferring.
Read `references/epistemics.md` for the full confidence framework and phrasing guide.
Whoever writes the answer, you or a synthesizer, must follow it.

## Understand the target and the question

Parse what the user is asking.
The **target** is usually a chunk of code, a pattern, a feature, or a named design decision.
The **question** is usually a design rationale, a tradeoff, a motivating edge case, an external constraint, dead code, or a broad history sweep.

If the target is vague ("why do we do it this way?" with no clear referent), make your best guess from conversation context (open files, recent edits, cursor location, what was just discussed).
State your interpretation briefly so the user can redirect if you're off, then proceed.

## Establish the code anchor

Before investigating, anchor the investigation in concrete code.
You need:

- The relevant file path(s) and line range(s)
- The key symbols (function names, class names, constants)
- An initial commit list. The last few commits touching the target.
- PR numbers from merge commits (pattern `(#1234)` or `Merge pull request #1234` in the subject line)
- The decision records that name the target, in `docs/decisions/` at the root or inside a package

Build this inline.

```bash
# Blame target lines for last-touch commits
git blame -L <start>,<end> <file>

# Full file history, with patches, through renames
git log --follow -p -- <file>

# Last N commits touching the file, PR numbers visible
git log --oneline -20 -- <file>

# Extract PR numbers from a commit message
git log -1 --format=%B <commit>
```

Pull PR bodies and discussion via `gh` for any substantive commits:

```bash
gh pr view <number> --json title,body,author,createdAt,mergedAt,labels,closingIssuesReferences,comments,reviews
```

Capture this as seed context (file paths, symbols, commits, PR numbers, linked ticket IDs, decision records).

## Investigate

### Discovery

List the evidence sources this session can reach, one coverage map over seven evidence categories:

1. Source control history
2. Issue / ticket tracker
3. Long-form documents
4. Real-time team chat
5. Infrastructure observability
6. Error / exception tracking
7. Product analytics warehouse

Source control is always available through git, and its pull requests through `gh`.
The issue tracker is GitHub Issues, also through `gh`.
For anything else, list the MCP servers the session offers and map each one to one evidence category, using the MCP name, server instructions, tool names, and resource descriptors.
If an MCP could fit more than one category, choose the one matching its primary evidence.
Record ambiguous cases in the coverage map.
An MCP that holds none of these kinds of evidence, such as one for a build tool or a browser, is not a source.

Aim for a complete **coverage map**, not a minimal one.
Document the null, don't skip the search.
A source you could not reach (`gh` missing or not signed in, no network, an MCP that refused) is a gap: report it with the error you got, never as "nothing found".

### One pass, when git and GitHub are the only sources

When no MCP maps to a category, run the investigation yourself, with no investigators and no synthesizer.

1. Follow `references/sources/code-archaeology.md`, then `references/sources/github-issues.md`.
2. Run the queries of `references/sources/incident-postmortem.md` inside both **if the target code looks defensive** (null checks, retry logic, timeout handling, rate limiting, feature flags, egress guards, OOM handlers).
3. Work to the sections "Operating posture", "Investigation instructions" and "Epistemic discipline" of `references/investigator-prompt.md`: quote, record every query, keep the contradictions. Both sources are yours, so follow a reference from one into the other yourself.
4. Write the answer in the output format of `references/synthesizer-prompt.md`, and run its quality check before you present it.

### Parallel investigators, when another source exists

Spawn one investigator per source, each a subagent that inherits the session's model.
Launch them in a single message and in the foreground (`run_in_background: false` on each call), so that they run concurrently and every finding is back before you go on.
Don't ask one agent to cover multiple sources.
An investigator needs the tools of its source, so do not give it an agent type that lacks them.
Investigators still shouldn't write anything.

Each investigator gets:

1. The base prompt from `references/investigator-prompt.md`
2. The playbook of its category, when `references/source-playbook.md` lists one, adapted to the source at hand
3. The cross-cutting `references/sources/incident-postmortem.md` **if the target code looks defensive** (null checks, retry logic, timeout handling, rate limiting, feature flags, egress guards, OOM handlers)
4. The code anchor (file paths, symbols, commit hashes, PR numbers, ticket IDs, decision records)
5. The user's original question

Each entry of the roster names the category and the kind of "why" it uniquely surfaces.
Use it to know what to expect back, how to name a gap when a category returns empty, and (only in the rare provably-irrelevant case) to justify a skip.

1. **Source control investigator**. Decision records, git history, `gh` for PRs, code comments, tests. Always spawn. The only guaranteed source. Best at surfacing *implementation-time rationale captured during review*.

2. **Issue / ticket tracker investigator** (GitHub Issues through `gh`, or e.g. a Linear, Jira, Plane, Shortcut MCP). Best at surfacing *the product or business forcing function*. Strongest when the why is external to engineering.

3. **Long-form documents investigator** (e.g. Notion, Confluence, Google Docs, Coda MCP). Best at surfacing *long-form design rationale*. Where the why is written out before it becomes code.

4. **Real-time team chat investigator** (e.g. Slack, Discord, Microsoft Teams, Mattermost MCP). Best at surfacing *real-time deliberation that never reached a doc*. Especially important when the source control, ticket, and doc paper trail is thin.

5. **Infrastructure observability investigator** (e.g. Datadog, New Relic, Honeycomb, Grafana, Splunk MCP). Infra/runtime view. Best at surfacing *infrastructure and runtime reality that motivated the code*. Strongest when the target reacts to an infra signal (timeouts, retries, rate limits, circuit breakers).

6. **Error / exception tracking investigator** (e.g. Sentry, Rollbar, Bugsnag, Airbrake MCP). Best at surfacing *the specific exceptions and error trajectories that motivated defensive or corrective code*. Strongest for catch blocks, null guards, type checks, retries, and other defenses.

7. **Product analytics warehouse investigator** (e.g. Databricks, Snowflake, BigQuery, ClickHouse, dbt, Redshift MCP). Product/data view. Best at surfacing *product and data reality that shaped the code*. Strongest for flag-gated code, experiment-driven ships, data migrations, and "where did this number come from" questions.

Only skip an investigator with an **explicit, written justification** that goes in the final "Sources consulted" section.
Two valid reasons:

- **No MCP is available for that category** in this environment. Flag this as a gap, not a choice. Example: "Real-time team chat skipped. No matching MCP available, so the conversational record was not searchable."
- **The source is provably irrelevant**, not just "probably irrelevant." A high bar. Example: "Error / exception tracking skipped. Target is a build-time script with no runtime code path."

If your scope assessment suggests a single-commit trivial target where the PR description already contains the complete answer, you may answer in one pass **only after** confirming that the searches of the other sources would be redundant.
Say so explicitly.
This should be rare.

Then spawn one synthesizer subagent in the foreground (`run_in_background: false`), which also inherits the session's model and needs the tools of every source, because its quality check spot-verifies citations.
The synthesizer gets:

1. The investigator findings, including any null results and any categories skipped with justification
2. The code anchor (file paths, symbols, commit hashes, PR numbers, ticket IDs, decision records)
3. The user's original question
4. The epistemics framework from `references/epistemics.md`
5. The synthesizer prompt template from `references/synthesizer-prompt.md`

## Present

Present the answer to the user.
You may lightly edit a synthesizer's output for clarity or add context from the conversation, but **do not rewrite the confidence language**.

## Output format

The output structure is the one in `references/synthesizer-prompt.md`: The question, The code in question, What we found, What we can reasonably infer, Competing hypotheses, What we don't know, Sources consulted, Confidence summary.
Adapt as needed, but keep the confidence separation intact, and keep Sources consulted as one line per evidence category, including the ones that returned nothing, could not be reached or were skipped, with the reason.

After the Sources consulted block, if the user's `why` question is a precursor to actually changing this code, convert the lineage findings into a Preserve / Change / Avoid / Risk constraint set suitable for planning the change.

## Common failure modes to avoid

- **Recency bias**. Assuming the most recent commit is authoritative. The current shape is often the accretion of many earlier decisions. Trace back.

## Reference files

- `references/epistemics.md`. Confidence tiers and phrasing guide. Every answer must follow it.
- `references/investigator-prompt.md`. Base prompt template for investigator subagents, and the posture of a single pass.
- `references/source-playbook.md`. Index pointing at the category playbooks below.
- `references/sources/code-archaeology.md` and `references/sources/github-issues.md`. The playbooks for the two sources every repository has.
- `references/sources/incident-postmortem.md`. The cross-cutting angle for defensive code.
- `references/synthesizer-prompt.md`. Prompt template for the synthesizer subagent, including the output format.
