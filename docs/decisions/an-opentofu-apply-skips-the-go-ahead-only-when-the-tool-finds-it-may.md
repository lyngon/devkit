# An OpenTofu apply skips the go-ahead only when the tool finds it may

An OpenTofu command that writes runs without a go-ahead only as the apply of a saved plan that the tool of `build:live-mutation` proposed in its OpenTofu form, and only when the tool finds that a rule file, as it is on the default branch of origin, names the plan's root module unprotected, and that no resource change of the frozen plan deletes or replaces anything.
The agent still judges what a plan cannot show, such as an in-place upgrade with no way back, and asks whenever it is in doubt, but never runs without a go-ahead where the tool refuses.
Such a run owes the `no-changes` check that the OpenTofu form adds and no other, and its action record names the rule file and says that no go-ahead was asked.
[A go-ahead is an answer or a merge, never a permission prompt](a-go-ahead-is-an-answer-or-a-merge-never-a-permission-prompt.md) names the weak point, whether the agent sees the target as protected and the mutation as irreversible, and for an OpenTofu plan the tool can read both.

## Considered options

- The agent alone judges the target and whether the apply can be undone, as for any other command. A replace buried in a long rendering is the likeliest wrong call, and the plan states it exactly.
- The agent names the rule file, and the tool checks only that it exists. Whether its prose covers the root module stays the agent's reading of a sentence.
- The rule files of the working tree count. An agent that the tool refused could then unblock itself by adding its root module to a rule on its own branch.
- Any OpenTofu write that the agent judges can be undone skips the go-ahead, a `state` command, `import` and `force-unlock` included. Only a saved plan shows its effect before it runs, and the other writes are rare.
- The OpenTofu form passes other plan arguments through, such as `-target` or `-replace`. No root module needs one yet, and each changes what the `no-changes` check must run, so a plan that needs one goes through the generic form, which always waits.
- A run without a go-ahead owes the full set of checks. Those exist for the owner's review before the run, and here nobody reviews before.

## Consequences

- The tool runs git, which joins `lyngon.scriptTools`, and the commands of its OpenTofu form run the `tofu` of the repository's shell, as the commands an agent writes for the generic form do.

Enforced by: `plugins/build/tests/live-mutation.sh`, and judgment for what a plan cannot show
