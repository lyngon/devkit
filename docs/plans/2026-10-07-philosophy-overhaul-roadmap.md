# Philosophy overhaul: roadmap

The order of the pieces that replace the devkit's gated workflow, and what the owner settled for each in the interview of 2026-10-07.
A fresh session reads this file before it designs or builds a piece.

This file is work in progress and transient.
A piece removes its own section in the change that lands it, and the last piece removes the file.
Anything that must outlive the work goes into a steering document, never here.

The full interview is session `0d296347-0098-4d53-9289-a5db6f44bc7d` of this repository's Claude Code project on the owner's machine.
Consult it only where this file is silent.

## Status

| Piece | State | Starts from |
| --- | --- | --- |
| `workflow` | Design written, twelve changes to build | [design](2026-10-12-workflow.md) |
| `agent-identity` | Inputs settled, no design | [seed prompt](../seed-prompts/004-agent-identity.md) |
| `issue-pipeline` | Inputs settled, no design | [seed prompt](../seed-prompts/005-issue-pipeline.md) |
| `github-repository-setup` | Inputs settled, no design | [seed prompt](../seed-prompts/006-github-repository-setup.md) |
| `rules-as-checks` | Inputs settled, no design | [seed prompt](../seed-prompts/007-rules-as-checks.md) |

The order is the order of the table.
`agent-identity` depends on nothing and may move earlier.
`issue-pipeline` needs `agent-identity` and `workflow`.
`github-repository-setup` needs `steering-documents`, `agent-identity` and `issue-pipeline`.
`rules-as-checks` is a long tail and may interleave.

Three things were parked as issues and are not pieces: review level B is `lyngon/devkit#13`, proving the structure on a first real context is `lyngon/devkit#14`, and the review of `steering-documents` added [Load a package's INTENT.md into context when an agent works on the package](https://github.com/lyngon/devkit/issues/16).

## The philosophy

The owner's ten points, as amended in the interview.

1. Agents read code well, so nothing the code shows is written down. Deducible is not the same as cheap, so the code must make it locally obvious or a check must enforce it.
2. Prose in the tree is for what the code cannot show: intent, principles, terms, decisions.
3. The tree holds what is true now, and git holds the past.
4. Agents decide and act, and record a decision the code cannot show in the same change.
5. An agent asks only before an irreversible action, or for a product or preference call that no run can settle.
6. The owner steers through steering documents and reviews results. Nothing waits for approval by default. A gate on requirements, a specification, a plan or tasks exists if and only if the owner asked for it explicitly.
7. Process is spent on proof, not on permission. A skill states what must hold and what proof is owed.
8. Debt is fixed when found, in its own change. Structure makes the right decision easy and the wrong one fail.
9. Whatever a tool can decide is checked by a tool. A rule without a check is debt.
10. Agents write the scripts and checks that do or prove the work, with the tool built for the task, such as jq for JSON, and never with logic hand-rolled in shell. Every tool is declared through Nix, pinned, and nothing comes from the ambient PATH. Highly custom logic is a Python program shipped as source next to the skill or check that uses it.

The inspiration is pstack by poteto.
The owner departs from it in one place: pstack keeps no intent or decisions in the tree and relies on an operator present for every task and on a searchable company record, and Lyngon has neither.

## Settled for every piece

### How the program is built

- In this repository, piece by piece. Each piece is designed from an empty page, and existing text must earn its way back in.
- Each piece gets a design file through `/discover:approach`, which the owner reviews. For `steering-documents`, `principles-and-why` and `workflow` the implementation then happens in the session without a plan file, and the owner reviews the pull request. The pieces after `workflow` are built with the new workflow.
- Questions in an interview carry short names, not numbers.

### Assumptions

- Claude Code is the only harness. Nothing is written to stay agent-neutral.
- Every development repository uses Nix and devenv, so a plugin for development may assume both.
- Only Linux is supported, most likely NixOS. Not macOS and not Windows.
- A plugin that is not for development, such as `writing`, must not assume Nix.

### Terms

Steering document, owner, operator, principle, rule, change and decision record are defined in [CONCEPTS.md](../../CONCEPTS.md).
"Convention", "ADR", "maintainer", "hard rule" and "working rule" are avoided.

### The admission test

> Write it down only when a competent agent, seeing just the files it opened, would plausibly contradict it, wrongly, with nothing failing.
> When a check can fail instead, write the check.

### Names

- Everything gets a name and is referred to by it, never by a bare number.
- An ordered item also carries a three-digit prefix before its name, as in `001-steering-documents.md`, so that it sorts in order. This covers sequential tasks, steps and queued seed prompts.
- Principles: the name is the file name. They are not ordered, so they carry no prefix.
- Rules: the name is the identifier the check reports.
- Decision records: the file is named after the decision. They are not ordered, so they carry no prefix, and "the next number" would be shared state that two branches both take.
- Issues and pull requests keep the forge's number. Inside the tree they are linked with the title as link text.

### The gate

Ask only before an irreversible action, or for a product or preference call that no run can settle.
Product direction is the owner's.
Always ask before a merge, a push to the default branch, a force-push, a tag, a release, a publish, a deploy, deleting data or a remote branch, any message outside GitHub, and spending money.
An agent that decides alone lists the decision in the pull request.

### pstack

- Upstream `https://github.com/cursor/plugins`, directory `pstack/`, MIT, read at commit `9f451cf875ad1239912762f67741e8e5ba6ac0f1` (2026-10-06). It has 51 skills, of which 24 are principles, and 23 playbooks under `skills/poteto-mode/playbooks/`.
- Everything enters through `/devkit:add-skill` and is rewritten, not merged.
- Taken in `principles-and-why`: the 24 principles and `why`.
- Taken in `workflow`: the skills `poteto-mode`, `figure-it-out`, `how`, `architect`, `arena`, `interrogate`, `tdd`, `no-comments` with its agent, `correct`, `show-me-your-work`, `benchmark-checklist`, `technical-writing`, `teach`, `bro`, and the playbooks `feature`, `refactoring`, `autonomous-run`, `prototype`, `bug-fix`, `opening-a-pr`. The owner asked that none of these be cut.
- On the shelf, vendored the first time a task needs it: `blast-radius`, and the playbooks `investigation`, `session-pickup`, `pause-safely`, `perf-issue`, `hillclimb`, `visual-parity`, `eval`.
- `create-verification-skill` and `maintain-verification-skill` go with issue 13, and `reflect` goes with `issue-pipeline`.
- Left out: `swarm`, `orchestrate`, both autopilots, `shipping`, `babysit`, `multi-phase-plan`, `recall`, `automate-me`, `setup-pstack`, `poteto-help`, `make-bot-ui`, `worktree-cleanup`, the two forensics playbooks and `authoring-a-skill`. `typescript-best-practices` is mined for lint rules in `rules-as-checks`. `unslop` is already vendored from another repository of the same author.
- Two patches the owner agreed to. The Comment Sicko agent is vendored for its keep-list and its flags, without its persona. `arena`, `interrogate` and `show-me-your-work` ask for different model families, and Claude Code offers several Claude models of one family, so their signal is weaker here.

### Facts looked up on 2026-10-07

- The `lyngon` organization is on the Free plan with 3 seats and 38 repositories, 28 private. The owner accepted the Team plan, 4 USD per user per month. On Free, rulesets and CODEOWNERS are enforced only in public repositories.
- `lyngon/devkit` is public, so anyone can file an issue on it. It has two rulesets, `main-ci` and `main-protect`, the default labels, and the issue types Task, Bug and Feature.
- Every merge method is enabled, the last eight pull requests landed as merge commits, and the squash message defaults to the commit messages.
- `gh` 2.101.0 supports `--type` and `--parent` on `gh issue create`, and `gh issue develop` links a branch to an issue.
- Anthropic's `claude` GitHub App is installed on selected repositories with write access to contents, issues, pull requests and workflows. It serves agents that run in GitHub Actions and cannot serve a session in a checkout.
- Agents push with the owner's token over https, with `gh` as the credential helper.
- `lyngon.com` is the only consumer. It has the structure enabled and holds no package.
- Claude Code 2.1.283, tested headless: `.claude/CLAUDE.md` loads at launch with no root file, a line `@../INTENT.md` in it imports the intent, a file under `.claude/rules/` without `paths:` loads at launch, and one with `paths:` loads after a matching file is read. An edit to the agent file applies after a clear, a compaction or a restart. Plugins cannot ship rule files.
- The four workflow plugins hold 5,762 of the 8,801 lines of plugin and shared text. Nine of their skills come from superpowers, and three skills of `discover` from mattpocock.

### Rejected, not to be proposed again

- A new repository or a long-lived rebuild branch.
- A machine user as the agent identity.
- GitHub Projects, a `new` label, a stored priority field, automatic closing of unanswered issues.
- Research at triage, and a second tier of task issues created by triage.
- A mistake ledger in the agent file, and one ledger file that every change appends to.
- An age limit for the ledger set by a variable on one machine.
- Twenty-four separate principle skills.
- The name `whoopsie`.

## workflow

Replace the two review gates, plans, owner gates and the ledger with a thin flow: a prompt or an issue in, proof and a pull request out.

Settled:

- The nine superpowers skills go: `build:plan`, `build:delegate`, `build:execute`, `build:finish`, `practice:tdd`, `practice:debug`, `practice:verify`, `review:request`, `review:receive`. The pstack skills above replace them by job: route (`poteto-mode`, `figure-it-out`, `feature`, `refactoring`, `autonomous-run`), understand (`how`, `teach`), design (`architect`, `arena`, `prototype`), prove (`tdd`, `show-me-your-work`, `benchmark-checklist`, `bug-fix`), review (`interrogate`, `no-comments`), learn (`correct`), write (`technical-writing`, `bro`), hand over (`opening-a-pr`).
- `poteto-mode` is patched heavily into Lyngon's own mode. Its autonomy section becomes the gate above. Every step in a vendored playbook must pass `prescribe-proof-not-steps`.
- The flow has no approval gate by default. It supports a gate on requirements, a specification, a plan or tasks when the owner asks for one explicitly, and only then.
- Scripts in skills and checks follow `use-purpose-built-tools`: the tool built for the task, declared through Nix and pinned, nothing from the ambient PATH, and Python shipped as source for highly custom logic.
- Test-first follows pstack's `tdd`: a failing test first for a bug when a cheap test path exists, and no test rather than a bad one. The rule "no production code without a failing test" goes.
- The mistake ledger. One file per mistake in a directory, named, holding the date, what happened and the pull request where it was caught. `correct` is its skill, patched from pstack's rule table to this ledger, and the agent invokes it itself on a correction from the operator, an accepted review finding or a revert. A failing check does not trigger it. On a repeat the check is written and the ledger file deleted. A repeat that no tool can decide becomes a file under `.claude/rules/`. A script prunes entries older than a limit that lives in the baseline module, 365 days by default.
- The pull request body has the sections Why, Decisions, What changed, Scope, Blast radius and Verification, in that order, and stays near 40 lines because it becomes the commit body. A Decisions entry names what was decided, the alternatives and how they were compared, the trade-off accepted and the steering document changed. "None" is written out. An entry that replaces a decision record says `replaces <name>`. pstack's Tradeoffs section folds into Decisions, and the "Rulings I made" list goes.
- The change is the unit. Squash is the only merge method, the pull request title is the commit subject in Conventional Commits form checked in CI, branch commits are free-form, and the commit-message hooks go.
- The interview skill's template gives each question a name.
- `encode-lessons-in-structure` is patched again to route a first occurrence to the ledger. `explain-the-number` and `prove-it-works` get back their pointers to `benchmark-checklist` and `show-me-your-work`, and `discover:why` its pointer to `how`. The sentence in `review-results-not-plans` about the gated skills is removed.
- These go with the piece: the three decision records about gates and plans, the terms Plan, Review gate, Owner gate, Pre-approval, Acceptance line, Dictated text and Mandated check, a new definition of Workflow, and `shared/WORKFLOW.md`. The lines of `conventions:engineering` are sorted into principles, rules and text a vendored skill already carries.
- These `docs/TODO.md` items become moot: the adversarial design review before planning, rehearsing a protocol early, one mechanism per plan, rehearsing `build:execute`, and the session hold in the build ledger.

Open, for the design to settle:

- Where the version bump happens. A bump inside each pull request conflicts once changes run in parallel. The proposal is one fragment file per change, folded into the version and changelog on the default branch.
- The provenance unit. The validator demands an `UPSTREAM.md` and a license per vendored skill, which is 14 pairs for one upstream commit.
- Which plugin holds which vendored skill, and how the mode gets into every session.
- What becomes of `discover:approach`, `discover:interview`, `discover:domain-model` and `discover:brainstorm`. `architect` replaces the design half of `approach`. The owner asked only for the superpowers skills to go.
- How a change to a skill is proven. The `eval` playbook is on the shelf for this.
- How a script shipped inside a plugin declares its tools through Nix, pinned: through the baseline module, whose pin is the consumer's `devenv.lock`, or in the script itself.
- What remains of the prerequisite system. Every development repository is now assumed to have Nix and devenv, so the `With devenv` sections lose their purpose for development plugins, while `writing` must still assume nothing.

## agent-identity

Agents act under their own GitHub identity, so that the forge can tell an agent from the owner and the owner can approve an agent's pull request.

Settled:

- One GitHub App owned by the organization, installed on all repositories, without the `administration` permission, so an agent cannot edit the rules that bind it.
- Created once by the owner, which needs one confirmation in a browser. Its private key is distributed through sops-nix.
- The baseline module ships a helper that mints installation tokens, which expire after one hour. The `repo` plugin's session hook sets `GH_TOKEN` and the git author in agent sessions only. A human shell stays the human.
- The Team plan, so that required review and CODEOWNERS are enforced in private repositories.
- The owner's global rule against attributing commits to agents is narrowed by the owner: no vendor lines in commit messages or pull request bodies, while the bot as author is fine.

Known limits:

- It is not a sandbox. The agent runs as the owner's Unix user and can ask the keyring for the owner's token. The identity catches honest mistakes and gives provenance.
- A bot cannot be an assignee, so an issue is claimed through its linked branch.

Open: the App's name and exact permissions, and whether the helper is a script or an existing tool.

## issue-pipeline

Tasks live in GitHub Issues, and `docs/TODO.md` and the seed prompts go.

Settled:

- An issue is the prompt. It states a goal, a done check that can pass or fail, what is known, and the constraints. Its type is Bug, Feature or Task.
- Triage ends in one of five outcomes: `ready`, `needs-info` (the reporter acts), `needs-decision` (the owner acts), closed as a duplicate with a link, or closed as declined citing the non-goal. Declining is reversible, so an agent may do it. An issue with none of the three labels is untriaged.
- Triage does only what stays true: it checks the type, finds duplicates, and makes sure a goal and a done check exist. It does no research. It splits an issue only when it holds two done checks.
- Issue text is untrusted input. The first read of every issue is by a classifier with no tools, which returns a structured verdict that a script applies. Routing is by author (an owner or member, a Lyngon agent, an outsider), never by repository visibility. For an outsider, triage classifies and finds duplicates only, never runs their steps, comments only from fixed templates, and the owner sets `ready`. For a trusted author a normal agent continues and may set `ready`.
- `needs-info` asks by restating: "I read this as X, and done would be Y. Correct?" It asks only what the reporter alone knows, for one round, and then the issue goes to the owner. A script returns the issue to triage when its last comment is not by the App. Unanswered issues are never closed automatically.
- An issue filed by an agent can never be `needs-info`, because its session is gone. The filing tool refuses an issue without a goal, a done check and evidence, and searches for a duplicate first.
- Priority is computed when an issue is picked, by a script, from guidelines the owner writes: type, labels, age and distinct human reporters. A debt issue is rare and says why the debt could not be fixed when found.
- The operator runs a command to pick the next issue or a named one. The claim is the linked branch from `gh issue develop`, and the pull request closes the issue.
- The done check is written before the work by someone other than the implementer, so the pull request's evidence is measured against it.
- Triage starts as a skill run from a checkout. It moves to GitHub Actions only once it is trusted.
- Issue forms require three fields: expected, actual, version.
- pstack's `reflect` and the queued session wrap-up item merge into one skill here. Its backlog output becomes issues. `correct` also runs at the end of a session through it.
- A mistake that belongs to every repository is filed on the devkit, where the duplicate check detects a repeat across repositories.
- The answer to a `needs-decision` issue is the only source of a line in an `INTENT.md` Priorities section.

Issues 13 and 14 were written by hand in this shape.
The existing `docs/TODO.md` entries are filed as issues or dropped when this piece lands.

## github-repository-setup

`repo:init` gains the GitHub side of a repository.

Settled:

- Init emits an idempotent script that the owner runs as themselves, because creating a ruleset is an act the agent identity must not hold. Init itself has never called the GitHub API.
- The script sets up the ruleset, a CODEOWNERS file for the steering documents, the labels `ready`, `needs-info` and `needs-decision`, the issue forms, and squash as the only merge method with the pull request title and body as the commit message.
- The steering paths are `INTENT.md`, `CONCEPTS.md`, `docs/decisions/` and `.claude/`. Covering all of `.claude/` also keeps an agent from loosening its own permissions in `settings.json`; the owner has not confirmed this last point.
- A check verifies that the ruleset exists.

Open:

- Under review level A every pull request needs the owner's approval. Level B is a ruleset with zero required approvals and required code-owner review. That combination is inferred from the documentation and must be tested on a scratch repository first.
- Declaring the settings of all repositories in one place, for example with OpenTofu's GitHub provider, is parked until drift has shown up twice.

## rules-as-checks

Every rule a tool can decide gets a check, and the prose that stated it is deleted.

Settled:

- The text of the `conventions` skills is sorted into principles and rules, and each rule moves into a linter, a hook or a validator. The `conventions` plugin and `docs/conventions/` are renamed.
- Linter configurations become templates that `repo:add-package` writes, as the existing `docs/TODO.md` item asks.
- pstack's `typescript-best-practices` is mined for lint rules instead of kept as prose.
- Five structure checks: a core library declares no third-party runtime dependency outside an allowlist, every core library has its layer lint configured, a package's name equals its directory and carries its context prefix, one non-test target per package or the policy is dropped, and strict type checking in every package. An addition to the allowlist is a decision and is listed in the pull request's Decisions section.
- The word rules of `shared/STRUCTURE.md` are checked by `prose-lint`, which checks none of them today.
- `readme-tree-mirrors-the-init-file-set` gets a check.
- A mistake gets its check on its second occurrence, through the ledger. A rule that is already written down gets its check without waiting.
- Three checks for rules that the workflow piece left as text, each of which deletes its sentence when it lands:
  - A manifest lint that fails on an exact pin in the dependencies of a library. It deletes the sentence "A library's manifest states constraints, never pins, and the lock file pins." from the standing instructions, `plugins/build/hooks/standing-instructions.txt`.
  - A check that refuses a hand edit of a file under `generated/` or `vendor/`. It deletes the sentence "Never edit a file under generated/ or vendor/ by hand; change its source or its generator." from the text of the `repo` hook, `plugins/repo/hooks/session-start-structure.txt`.
  - A check that refuses an imperative install, such as `pip install` or a global `npm install`. It deletes the sentences of the standing instructions that a check then carries, from "Nothing enters the environment without a declaration that a lock file pins".

This piece is a long tail.
One check per change is the expected shape.

## Review level B and its evidence

Parked as issue 13.
The interview settled what counts as evidence, which the issue only summarizes.

| Change | Sufficient evidence |
| --- | --- |
| Bug fix | The repro as a test that fails at the parent commit and passes at head, both in CI |
| Refactor | Test files untouched and green, an empty public API diff, identical fixture output |
| CLI or service | Captured output of the real command, before and after |
| Performance | One number before and after, the command, interleaved runs with their range |
| Nix, devenv, infra | The full check in a consumer fixture, and a closure diff |
| Data migration | Row counts before and after, and a second run that changes nothing |
| Deletion | Build, type check and lint green, with the reference search output |
| Skill or prompt | The same task run headless on old and new text, judged blind, transcripts kept |
| Steering document | The diff itself |

A repository earns level B only when CI drives its real surface.
