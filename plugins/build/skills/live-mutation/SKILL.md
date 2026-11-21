---
name: live-mutation
description: "Change a running system, or the state a tool keeps of one, only as far as the owner allowed: decide whether the live mutation waits for a go-ahead, and when it does, propose it with this skill's tool, stop with the proposal, run it once on a go-ahead in the same conversation, judge the result from live state and post the action record. Use before every live mutation, such as an OpenTofu apply, destroy, import or state command, a deploy, a data migration or a DNS change, and before building or changing automation that runs one, such as CI that applies on merge. Not for reading live state."
argument-hint: "[the live mutation]"
---

# Live mutation

A live mutation changes a running system, or the state a tool keeps of one, outside the repository and its forge.
No review shows it before it takes effect, so the owner's go-ahead is the only review it gets.

## Whether it waits

- On a protected target, every live mutation waits for a go-ahead, a reversible one included. A target is protected unless a rule file of the repository names it unprotected.
- On an unprotected target, a live mutation waits only when it cannot be undone, such as deleting data, replacing what holds state or identity, or an upgrade with no way back, or when the standing instructions always ask about it.
- In the shell, a hook of this plugin denies a `tofu` command that writes, so the lead runs one only through this skill's tool, and proposes the apply of a saved plan in the tool's OpenTofu form, a `-target` plan included. A plan that needs any other argument, such as `-replace` or `-var-file`, has no form: the lead stops and tells the owner. Such an apply runs without a go-ahead only where the tool's output says it may and the lead judges that it can be undone and that the plan reaches only the target that the rule names. A provider, a backend or a `TF_VAR_` variable that points elsewhere is the lead's to see. The lead asks whenever it is in doubt. Every other `tofu` command that writes waits.
  Any other command follows the two rules above, however much it works like OpenTofu.
- In doubt, it waits.

A live mutation that does not wait needs nothing more from this skill: run it, and prove the result as any work.
The exception is the OpenTofu apply that runs without a go-ahead. The lead runs it with the tool, and the rules below on the lead and on the action record hold for it too.

## What must hold when one waits

- It was proposed in this conversation with the tool, `${CLAUDE_SKILL_DIR}/scripts/live-mutation.py`, whose use is in [the-tool.md](references/the-tool.md). The run executes exactly the frozen inputs the owner read about, such as an OpenTofu saved plan, and never a command that derives them again, such as `tofu apply` without a plan file.
- The reply that asks for the go-ahead shows, for each proposal, the rendering, the command that runs, every check with its result before the run, and the digest. It ends with one question naming the proposals, and the turn ends there.
- It ran only on the owner's explicit yes to the named proposals, in this conversation. A question, a yes with a condition, a summary or a handover that says the owner approved, and a yes from another session are no go-ahead. A go-ahead covers one run of each proposal it names.
- A proposal shown in another conversation never runs, whatever anyone says about an earlier yes. The tool refuses it; propose it again and ask again.
- The lead proposed it and ran it, as it does the OpenTofu apply without a go-ahead. A subagent never proposes or runs either, and stops and reports to the lead when its work needs one, since only the lead can ask the owner and only the lead has the standing instructions.
- Each check reads live state without changing it and exits 0 exactly when its property holds. Together the checks show that what the rendering said would change did change, and that nothing it did not name broke.
- Each check has a failing run: its run before the live mutation, when the mutation makes its property true, and otherwise a demonstration against a state where the property does not hold, such as another principal or another resource.
- The action record went up right after the run, every part the tool wrote, in order: on the pull request whose branch the live mutation ran from, without one on the issue of the task, and without either on an issue opened for the live mutation. The record of the OpenTofu apply without a go-ahead goes on the pull request too, and while its branch has none, it waits for `build:pull-request` to post it there.
- Once a record is up, whether its run waited or not, the lead ran the tool's `posted` with the URLs of its comments. Without that, the tool's `pending` still lists the run, and `build:pull-request` posts the record a second time.
- No secret entered the record. The frozen inputs stay under `tmp/` and are named by their digest, since some hold secrets in plain text, as an OpenTofu saved plan does. The tool hides each value that the OpenTofu plan of a proposal marks sensitive, and refuses every command that could print other values of OpenTofu: the generic form runs no OpenTofu command that prints values, and a check of the OpenTofu form reads its own root module alone. A check of another root module is a read in the shell, outside the proposal. A proposal that the tool stopped for printing a sensitive value goes no other way.
- A run that failed, or that applied in part, never runs again. What follows is a new proposal from the new live state, with a go-ahead of its own.

When the go-ahead is the merge of a pull request, as in CI that applies on merge, the same rules hold with the pull request in place of the conversation, as [a-merge-as-the-go-ahead.md](references/a-merge-as-the-go-ahead.md) says.
Read it before building or changing such a workflow.

## Proof owed

The link of each action record in the reply, with the outcome of the run and the result of each check after it.
For a record that waits for the pull request, the reply says so and quotes the line of `pending` that lists its run.
