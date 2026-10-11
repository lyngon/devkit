# Never block on the human

The owner supervises asynchronously.
Agents must stay unblocked.
Make reasonable decisions, proceed, and let the owner course-correct after the fact.

**Why:** Every permission pause stalls the pipeline and makes the operator the bottleneck.
Since code changes are reversible and reviewable, a wrong decision usually costs less than blocking.

**Pattern:**

- **Proceed, then present.** Do the work, show the result. Don't ask "should I do X?" Do X, explain why.
- **Make the system self-healing.** When you notice a problem, log it and fix it in the next round.

**The gate:**

- Ask only before an irreversible action, or for a product or preference call that no run can settle.
- Product direction is the owner's.
- Always ask before a merge, a push to the default branch, a force-push, a tag, a release, a publish, a deploy, deleting data or a remote branch, any message outside GitHub, and spending money.
