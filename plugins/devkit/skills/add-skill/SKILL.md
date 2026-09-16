---
name: add-skill
description: Add a skill to the Lyngon devkit. Given a third-party skill name or URL, find it, vet it against the review checklist, and install it as a pinned plugin or a vendored skill under the right concern. Given a description of a skill that should exist, search for prior art, design it with discover:approach, then install an existing one or create a new one. User-invoked only, devkit repository only.
disable-model-invocation: true
argument-hint: "<skill name, URL, or description of the skill you want>"
---

# Add a skill

## Overview

One entry point for growing the marketplace, so every addition follows the same policy: provenance recorded, license checked, text read by a named person, placed by concern, validator green.

## When to use

- The user names or links a third-party skill they want in the devkit.
- The user describes a skill that does not exist yet.

## When not to use

- Outside the devkit repository. Check that `.claude-plugin/marketplace.json` exists and its `name` is `lyngon`; otherwise stop and say this skill only maintains the devkit.
- Updating a skill that is already in the catalog. Say so and point at `docs/TODO.md` (the bump flow) instead of installing twice.
- Editing an in-house skill. Edit it directly.

## Step 0: Classify the request

Read `$ARGUMENTS`.

- **Case A, existing skill**: a URL, an `owner/repo` or `owner/repo/path`, a skill name with an author, or a name that is clearly a product ("the unslop skill").
- **Case B, new skill**: a description of behaviour ("a skill that wraps up a conversation and...").
- **Unclear**: ask one question with both readings, and wait.

Check the catalog first: `grep -rl` the name in `plugins/*/skills/*/UPSTREAM.md` and `catalog/`. If it is already there, stop as described above.

## Case A: an existing skill

### A.1 Find it

Follow [references/find.md](references/find.md).
Resolve to an exact upstream: repository URL, path inside it, and the commit you inspected.
Clone with `--depth 1` into the scratchpad; never into the repository.

### A.2 Confirm it is the right one

Show the user: upstream, path, license, size (files and lines), the frontmatter description, and in your own words what the skill does and does not do.
If several candidates match, list them with the same facts and ask.
Wait for confirmation.

### A.3 Review it

Work through [SKILL-REVIEW.md](SKILL-REVIEW.md) file by file.
Read everything in the skill directory, including scripts and references.

### A.4 Present findings

Present every section's findings, including "none found", and the verdict.
A **blocked** verdict ends here unless the user overrules it in writing; record the overruling in the provenance record.
No license: follow [references/license-request.md](references/license-request.md) and stop.

### A.5 Human review, then kind and placement

Ask the user to read the full upstream text; show it inline when it is under about two hundred lines, otherwise give the paths.
Only after they say they have read it may their name go into the provenance record as reviewer.

Derive the kind, do not ask for it:

- **Vendor** when the upstream is a bare skill directory with no `plugin.json`, when only a subset of a plugin is wanted, or when a patch is needed to fit the devkit.
- **Pin** when the upstream is a plugin used whole and unmodified.

Then propose the concern: an existing plugin under `plugins/` whose concern the skill serves, or a new one. Give a recommendation, list the alternatives, and wait.

### A.6 Install

Follow [references/install.md](references/install.md) for the exact files.
Run `devenv test` and fix what fails without disabling anything.
Do not commit; end by offering a Conventional Commits message.

## Case B: a new skill

### B.1 Search for prior art

Use the sources in [references/find.md](references/find.md) with three or four phrasings of the described behaviour.
Keep every plausible hit with upstream, path, license and a one-line summary.

### B.2 Design it

Invoke `discover:approach` with the user's description and the prior-art list as context.
The interview must settle: the skill's name (a noun that reads after the concern, as in `/discover:approach`), the concern it belongs to, what it does and does not do, user-invoked or model-invoked, inputs and outputs, and the one prompt that must trigger it and one that must not.
Whenever a prior-art hit covers a settled requirement, say so in the interview.

### B.3 Decide

Present the two options with a recommendation:

- **Install an existing one**: say what it does and does not do relative to the settled design. If agreed, continue at A.3 with that upstream.
- **Create a new one**: if agreed, follow [references/create.md](references/create.md).

Do not commit; end by offering a Conventional Commits message.
