# receive

- **Upstream**: <https://github.com/obra/superpowers>
- **Upstream path**: `skills/receiving-code-review`
- **Upstream name**: `receiving-code-review`
- **Upstream version**: 6.4.1
- **Upstream commit**: 5bf4e78011075bcfc0dc295f0724994cd123ee71
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-09-23 by Anders Åström

## Why it is here

The other half of review.
It stops the two failure modes that waste a review: agreeing performatively and implementing blindly.
With the user reviewing the finished branch, feedback arrives in batches, and the rule to clarify every unclear item before implementing any of them is what keeps a batch from being half-applied.

## Local patches

- Renamed `receiving-code-review` to `receive`; the H1 is "Receive a code review" (upstream: "Code Review Reception").
- Rewrote the description to say what the skill does and when to use it, naming the user, a reviewer subagent and an external reviewer as sources and keeping upstream's "before implementing suggestions, especially if unclear or technically questionable" trigger.
- "your human partner" became "the user" throughout, including the example transcripts ("The user: 'Fix 1-6'").
- The two "your human partner's rule:" quotes became plain rules in the skill's voice: "Rule: external feedback gets checked carefully, not implemented on trust." and "Rule: the reviewer and you both answer to the user; a feature nobody needs is not added because a reviewer suggested it."
- "(explicit instruction-file violation)" became "(a phrase many instruction files forbid)".
- "Simple fixes (typos, imports)" became "Simple fixes (spelling mistakes, imports)"; the original word is a baseline hook name the prerequisite validator rejects.
- Added a "From a reviewer subagent" source between the user and external reviewers: treated as external (verify first), with the instruction to open each file and line reference before anything else and to push back with the reference when a finding does not match the code.
- Dropped the "Overview" heading; its one sentence now opens the body.
- Sentence-cased the headings; replaced the hyphen-as-dash connectors ("STOP - do not", "Good catch - ") with colons; removed the em dashes; reflowed prose to one sentence per line; gave every fenced block the `text` language; the three-sentence core principle is three lines.
- Expanded contractions and telegraphic phrasing in the rule blocks and examples ("Need legacy for backward compat" became "The legacy path is needed for backward compatibility") without changing the rules.
- "top-level PR comment" became "top-level pull request comment".
- Kept the response pattern, forbidden responses, unclear-feedback rule, YAGNI check, implementation order, push-back rules, correction wording, common mistakes, real examples and the GitHub thread-replies section.

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-09-23.

- Security: none found. Pure prompt text; no scripts, hooks, network, credentials, tool restrictions, overrides or encoded content. The `gh api` line is an example of replying in a thread and runs only when the agent chooses to.
- Quality: description rewritten. Trigger check: "the reviewer says to remove the legacy path" triggers; "write a review of this PR" does not. Body 205 lines, proportionate. Dependencies: optionally the GitHub CLI. Scope stated. Agent-neutral.
- Fit: the author's personal rules rewritten as plain rules; a "reviewer subagent" source added for the build plugin; the word that trips the baseline term list replaced. Does not write devkit-owned files. Overlap: none.
- License: MIT at the repository root.
- Verdict: clear with patches, all applied.
