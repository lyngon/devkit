# Plan and approach rules

Seed prompt for a fresh Claude Code session in the devkit repository.

Add three rules to `build:plan`, a shell convention skill to the `conventions` plugin, and one sentence to `discover:approach`.
Each comes from a defect that a plan dictated verbatim in lyngon.com sessions on 2026-09-27; the rules are general.

This is a bounded change: no design file and no plan file.
Work on a branch named `fix/plan-and-approach-rules`.
Do not commit until I have reviewed the files; after the review, commit by concern in Conventional Commits form.
Bump the version of every plugin you change and add a `CHANGELOG.md` entry to each.
Run `devenv test` before handing over and report its output faithfully.

## 1. Every plan-mandated check is proven both ways

A plan dictated `if tofu plan ... | grep -q 'Error acquiring the state lock'` under `set -uo pipefail` as the check that a state lock works.
`grep -q` exits at the first match, the producer keeps its own non-zero status, and under `pipefail` the pipeline fails exactly when the property holds.
Nobody saw it until the live step, because the plan's self-review has nothing that would.
The same plan's check of an organization policy had a control (shown passing and failing) and was fine.

Change, in `plugins/build/skills/plan/SKILL.md`: every verification the plan mandates (a script, a command with an expected output, a check a task runs before proceeding) is shown failing when its property does not hold and passing when it does, the same discipline the tasks apply to code.
Add it to the self-review list, and to "No placeholders" where a check without a control is the placeholder.

## 2. Dictated prose is checked against the documents and the plan's own findings

The whole-branch review in lyngon.com found three defects in prose the plan dictated verbatim, none in the implementation: an ADR sentence that contradicted an existing ADR, a README recovery step that omitted the owner gate the repository's CLAUDE.md imposes on destructive commands, and an ADR claim that the plan's own analysis had already shown false.

Change, in the plan self-review: every prose block the plan dictates (ADR text, README steps, CLAUDE.md lines, CONCEPTS.md entries) is checked against the existing ADRs, the gates and rules in CLAUDE.md, and the findings recorded earlier in the same design or plan.
Add one line to "With the Lyngon documents", which already says which decisions become ADRs.

## 3. Owner-facing commands run in any shell

A plan step meant for the owner used `${PIPESTATUS[0]}`, which printed nothing in the owner's zsh.

Change: `build:plan` says that a command a person runs by hand is POSIX sh, or is run through `bash -c` explicitly, and points at the shell convention below for the rules an implementer meets while writing scripts.

## 4. A shell convention skill

The `conventions` plugin has no shell skill; `engineering` applies to every file, and `nix` says that a script a hook or task runs is a `writeShellApplication`.
Create `plugins/conventions/skills/shell/SKILL.md` on the pattern of `python` and `nix`: `user-invocable: false`, `paths` for `**/*.sh`, `**/*.bash` and `scripts/**`, `name` equal to the directory, background knowledge.
Content, kept short:

- Under `set -o pipefail`, capture a command's output first and match the variable; never pipe a command whose failure is expected into `grep -q`.
- A command meant for a person to run by hand is POSIX sh or is run through `bash -c`; no bash-only syntax such as `PIPESTATUS` in documentation.
- `set -euo pipefail` at the top of every script, shellcheck clean, formatted by shfmt.
- Under "With the Lyngon baseline": a script a hook or task runs is a `writeShellApplication` with its dependencies in `runtimeInputs`.

Update `plugins/conventions/README.md` where it lists the skills, and stage the README plugin table that the hook regenerates.
Check `docs/conventions/prerequisites.md` for how the baseline sentence must be marked.

## 5. `discover:approach` may open with the choice of approach

Step 5 of the architectural path proposes approaches after the interview.
In lyngon.com the choice of approach was the root of the design tree, so the session folded it into the first question, which the skill does not say is allowed.

Change: one sentence in `plugins/discover/skills/approach/SKILL.md`, in step 4 or 5: when the choice between approaches decides everything downstream, the interview opens with it, and step 5 becomes a confirmation of the choice with the trade-offs stated.

## Out of scope

- Owner gates and operational tasks: `docs/seed-prompts/owner-gates.md`.
- Build scripts and templates: `docs/seed-prompts/build-scripts-and-templates.md`.
