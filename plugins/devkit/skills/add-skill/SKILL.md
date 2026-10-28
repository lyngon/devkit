---
name: add-skill
description: Add a skill to the Lyngon devkit. Given a third-party skill name or URL, or several paths of one upstream, find them, vet them against the review checklist, and install them as a pinned plugin or as vendored skills under the right concerns. Given a description of a skill that should exist, search for prior art, design it in an interview through discover:interview, then install an existing one or create a new one. User-invoked only, devkit repository only.
disable-model-invocation: true
argument-hint: "<skill name, URL, paths of one upstream, or description of the skill you want>"
---

# Add a skill

## Overview

One entry point for growing the marketplace, so every addition follows the same policy: provenance recorded, license checked, text read by a named person, placed by concern, validator green.

## When to use

- The user names or links a third-party skill, or several paths of one upstream, that they want in the devkit.
- The user describes a skill that does not exist yet.

## When not to use

- Outside the devkit repository. Check that `.claude-plugin/marketplace.json` exists and its `name` is `lyngon`; otherwise stop and say this skill only maintains the devkit.
- Updating a skill that is already in the catalog. Say so and point at `docs/TODO.md` (the bump flow) instead of installing twice.
- Editing an in-house skill. Edit it directly.

## Step 0: Classify the request

Read `$ARGUMENTS`.

- **Case A, existing skill**: a URL, an `owner/repo` or `owner/repo/path`, a skill name with an author, or a name that is clearly a product ("the unslop skill").
  Several paths of one upstream are one request.
  Every step of Case A covers each path, and A.6 installs them together.
  Paths of different upstreams are separate requests.
- **Case B, new skill**: a description of behaviour ("a skill that wraps up a conversation and...").
- **Unclear**: ask one question with both readings, and wait.

Check the catalog first.
The records of pinned plugins are in `catalog/`, and the records of vendored skills in `catalog/vendored/`, one per upstream:

```sh
grep -rl '<name>' catalog/
```

If the skill is already there, stop as described above.
If only its upstream is there, the skill joins that upstream's record.

When the request names a change of a design file under `docs/plans/`, read that change's row, and the sections of the design that it points at, before anything else.
The row settles the names, the destinations, the patches, the branch and the proof owed: take each from it and ask about none of them again.
Ask only where the row and what you find upstream disagree.

## Case A: an existing skill

### A.1 Find it

Follow [references/find.md](references/find.md).
Resolve to an exact upstream: repository URL, every path inside it that the request names, and the commit you inspected.
Clone with `--depth 1` into the scratchpad; never into the repository.
When the upstream already has a record under `catalog/vendored/`, inspect the commit that record names, because a record covers one upstream at one commit.
Taking a newer commit is a bump of everything vendored from that upstream, which is the bump flow in `docs/TODO.md`.

### A.2 Confirm it is the right one

Show the user, for each path: upstream, path, license, size (files and lines), the frontmatter description, and in your own words what the skill does and does not do.
If several candidates match, list them with the same facts and ask.
Wait for confirmation.

### A.3 Review it

Work through [SKILL-REVIEW.md](SKILL-REVIEW.md) file by file, once for each path.
Read everything in the skill directory, including scripts and references.

### A.4 Present findings

Present every section's findings, including "none found", and the verdict, for each path.
A **blocked** verdict ends here unless the user overrules it in writing; record the overruling in the provenance record.
No license: follow [references/license-request.md](references/license-request.md) and stop.

### A.5 Human review, then kind and placement

Ask the user to read the full upstream text; show it inline when it is under about two hundred lines, otherwise give the paths.
Only after they say they have read it may their name go into the provenance record as reviewer.

Derive the kind, do not ask for it:

- **Vendor** when the upstream is a bare skill directory with no `plugin.json`, when only a subset of a plugin is wanted, or when a patch is needed to fit the devkit.
- **Pin** when the upstream is a plugin used whole and unmodified.

Then propose the concern of each path, unless the change's row settles it: an existing plugin under `plugins/` whose concern the skill serves, or a new one. Give a recommendation, list the alternatives, and wait.

The concern also settles what the skill may assume.
A skill for development goes into a member of `all` and may assume a Lyngon development repository (Nix, devenv, the baseline, the documents and the workflow) and every other member of `all`.
A skill that must work anywhere goes into `writing`, or into a new plugin like it, and names no term of a development repository and no skill of another plugin.
`scripts/validate-shipped-text.py` holds `writing` to that, and a new plugin like it is named there beside `writing`.
Derive which of the two the skill is from its text, the way that check does: name every line that carries one of the check's terms, and say for each whether the sentence can be reworded or the skill is for development.
Membership of `all` is never a question: the validator puts every plugin outside the categories `devkit` and `bundle` in it.

### A.6 Install

Follow [references/install.md](references/install.md) for the exact files.
Run `devenv test` and fix what fails without disabling anything.
Commit the result as one commit on the feature branch (on the default branch, create one first), with the message from [references/install.md](references/install.md).
Then finish the change, as below.

## Case B: a new skill

### B.1 Search for prior art

Use the sources in [references/find.md](references/find.md) with three or four phrasings of the described behaviour.
Keep every plausible hit with upstream, path, license and a one-line summary.

### B.2 Design it

Invoke `discover:interview` with the user's description and the prior-art list as context.
The interview must settle: the skill's name (a noun that reads after the concern, as in `/discover:interview`), the concern it belongs to, whether it is for development or must work anywhere, what it does and does not do, user-invoked or model-invoked, inputs and outputs, and the one prompt that must trigger it and one that must not.
Whenever a prior-art hit covers a settled requirement, say so in the interview.

### B.3 Decide

Present the two options with a recommendation:

- **Install an existing one**: say what it does and does not do relative to the settled design. If agreed, continue at A.3 with that upstream.
- **Create a new one**: if agreed, follow [references/create.md](references/create.md).

Commit the result as one commit on the feature branch (on the default branch, create one first), with the message from the reference you followed.
Then finish the change, as below.

## Finish the change

The commit holds the skill, and the change owes more before it is done.
Each skill that it adds owes an eval case for the behaviour it claims, and the suite's score at the base commit and at head, as the README's section "Evals" describes.
A change of a design file also owes everything else that its row lists.

When nothing more is owed, invoke `build:pull-request`, which runs the full check, pushes the branch and opens the pull request.
The description names every upstream path with its commit, and who read the text there.
The design file that the request named stays: it covers more than this change, and only the change that the design names removes it.
