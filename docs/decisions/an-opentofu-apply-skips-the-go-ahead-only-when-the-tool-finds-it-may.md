# An OpenTofu apply skips the go-ahead only when the tool finds it may

An OpenTofu command that writes runs without a go-ahead only as the apply of a saved plan that the tool of `build:live-mutation` proposed in its OpenTofu form, and only when the tool finds that a rule file, as it is on the default branch of origin, lists the plan's root module or a directory above it under `unprotected-roots:` in its frontmatter, and that no resource change of the frozen plan deletes, replaces or imports anything.
A plan that needs an argument beyond the form's own, such as `-target`, is proposed in the OpenTofu form as well, which writes the argument into its commands and then always waits, since the tool judges the route of a plan of the whole root module only.
An argument that the form does not take is refused, and the agent stops and tells the owner.
The agent still judges what a plan cannot show, such as an in-place upgrade with no way back, and whether the plan reaches only the target that the rule file names, since a provider, a backend or a `TF_VAR_` variable can point elsewhere.
It asks whenever it is in doubt, and never runs without a go-ahead where the tool refuses.
The lead runs it, and a subagent stops and reports it to the lead, as for every OpenTofu write.
Such a run owes the `no-changes` check that the OpenTofu form adds and no other, and its action record names the rule file and says that no go-ahead was asked.
[A go-ahead is an answer or a merge, never a permission prompt](a-go-ahead-is-an-answer-or-a-merge-never-a-permission-prompt.md) names the weak point, whether the agent sees the target as protected and the mutation as irreversible, and for an OpenTofu plan the tool can read both.

The tool guards against a wrong judgment and an accident, such as a check that writes the frozen plan or a ref that was never fetched.
It does not guard against an agent that sets out to rewrite the tool's files under `tmp/`, its environment, its PATH or the repository's own `.git`, such as its config with a `url.<base>.insteadOf` or its refs, since a check that runs in the agent's own session cannot stop that.

## Considered options

- The agent alone judges the target and whether the apply can be undone, as for any other command. A replace buried in a long rendering is the likeliest wrong call, and the plan states it exactly.
- The agent names the rule file, and the tool checks only that it exists. Whether its prose covers the root module stays the agent's reading of a sentence.
- The declaration is a list of globs, as under `paths:`, or a map with room for other kinds of target. A directory is how OpenTofu names a root module, and no other kind of target needs a declaration that a tool reads.
- The rule files of the working tree count. An agent that the tool refused could then unblock itself by adding its root module to a rule on its own branch.
- The rule files count as they are at `refs/remotes/origin/HEAD`, with no call to origin. One `git remote set-head` points that ref at the agent's own branch, and a fetch that never ran keeps a declaration that origin removed.
- Any OpenTofu write that the agent judges can be undone skips the go-ahead, a `state` command, `import` and `force-unlock` included. Only a saved plan shows its effect before it runs, and the other writes are rare.
- A plan that needs another argument goes through the generic form, which always waits. The generic form cannot read the plan's JSON, so it writes and posts each value that the plan marks sensitive and that `tofu` prints.
- The generic form names the root module of its plan, so that the tool reads that plan's JSON. The agent then still writes the plan commands and the `no-changes` check by hand, and nothing checks that the root module it names is the one it planned.
- The OpenTofu form passes any plan argument through. Each argument changes what the `no-changes` check must run, and some leave it no run that fails, as `-replace` does: with it the check fails after the run too, and without it the check passes before the run when the replace is the only change. So the form takes only the arguments that it has a rule for.
- A subagent runs it through the tool, since nobody waits for the owner. A subagent does not get the standing instructions, so it judges with less context than its lead, and one actor that holds live state keeps the runs and their records in one place.
- A run without a go-ahead owes the full set of checks. Those exist for the owner's review before the run, and here nobody reviews before.

## Consequences

- The tool runs git, which joins `lyngon.scriptTools`, and the commands of its OpenTofu form run the `tofu` of the repository's shell, as the commands an agent writes for the generic form do.
- A run without a go-ahead needs origin to answer, since the tool asks it for its default branch.

Enforced by: `plugins/build/tests/live-mutation.sh`, `plugins/build/hooks/tofu-writes-go-through-live-mutation.py` for a subagent, and judgment for what a plan cannot show
