---
name: review
description: "Adversarial review of a change by several reviewer subagents on different models, each given the same prompt, rubric and code-quality lens, synthesized by you into one verdict (act on, consider, noted, dismissed) without applying any change. Use only when the operator asks for it: 'interrogate', 'adversarial review', 'multi-model review', 'challenge this', 'stress test this code', 'find blind spots', 'tear this apart', or when build:architect puts a design under pressure. Not the routine review of every change."
argument-hint: "[the change to review: files, a diff or a branch; the current branch by default]"
---

# Review

Spawn one reviewer per model to adversarially review code changes.
Each reviewer gets the same prompt and rubric.
The adversarial signal comes from model diversity, not assigned personas.

The deliverable is a synthesized verdict.
Do NOT auto-apply changes.

## Determine the scope

Identify what to review from context:

- If the operator points at specific files or a diff, use that
- If on a feature branch, run `git diff main...HEAD` (or the appropriate base branch) for the full changeset
- If the operator's message references recent work, gather the relevant files

Package the diff (or file contents) plus any surrounding context files the reviewers need to understand the code.

## State the intent

Before spawning reviewers, state the intent explicitly.
Derive this from:

- The operator's message
- Commit messages
- The pull request description if one exists
- The design file under `docs/plans/` if the branch has one
- The code itself

Write one clear paragraph.
If you're unsure about the intent, ask the operator before proceeding.

## Spawn reviewers

Spawn two reviewers in a single message and in the foreground (`run_in_background: false` on each call), so that they run concurrently and every finding is back before you go on.
Give each a different model where the harness offers more than one (the Agent tool's `model`), none of them weaker than the model that did the work, and at least one of them different from it.
Reviewers read and search, and they change nothing.

Read `references/reviewer-prompt.md` and fill in the template with:

1. The stated intent
2. The diff or file contents
3. The review rubric from `references/rubric.md`
4. The code-quality lens from `references/code-quality-review.md`

The same filled template goes to all reviewers, so every model applies the code-quality lens.

## Synthesize

As results come back, build a unified picture:

1. **Parse all findings** from the reviewers
2. **Identify consensus**. Findings raised by 2+ models independently are highest signal.
3. **Identify lone-model findings**. Still worth reading, but weight accordingly.
4. **Deduplicate**. Different models may describe the same issue differently. Merge these and note which models raised it.
5. **Note disagreements**. If one model flags something and another explicitly says the opposite, that's useful context for the verdict.

## Lead judgment

You are the lead reviewer, a pragmatic senior engineer, not a neutral aggregator.

Read `references/lead-judgment.md` for the full framework.

Categorize every finding using these buckets:

- **Act on**. Real issues affecting correctness, security, or maintainability given the actual goals. These would block a real pull request.
- **Consider**. Legitimate points, but you're not sure they outweigh the cost of addressing them right now. Worth the operator's attention.
- **Noted**. Technically valid but not actionable. Context-dependent, premature optimization, or low-impact given the current stage.
- **Dismissed**. Wrong, nitpicky, or missing context. Brief explanation why.

For each finding, include:

- Which model(s) raised it
- The category (act on / consider / noted / dismissed)
- A one-line rationale for the categorization

## Output format

Present the verdict in this structure:

### Intent

> [The stated intent paragraph from "State the intent"]

### Reviewers

- [Model name]: [N findings] (one bullet per reviewer)

### Act on

[Findings that should be addressed. For each: description, which models raised it, why it matters.]

### Consider

[Findings worth thinking about. For each: description, which models raised it, tradeoff involved.]

### Noted

[Valid but low-priority. Brief list.]

### Dismissed

[Rejected findings with brief rationale.]

### Agreement map

[Where did models agree, where did they diverge, and what does the pattern of agreement/disagreement tell us?]
