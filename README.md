# Lyngon devkit

The shared foundation for software development at Lyngon: the reusable pieces a repository needs to work the Lyngon way.

The Lyngon way is opinionated, and this repository exists to make those opinions cheap to follow and hard to drift from.

## The Lyngon way

- Dependencies come from [`devenv`](https://devenv.sh/) and [Nix](https://nixos.org/), never from a global install.
- A repository that adopts the structure is laid out by package kind (`apps/`, `libs/`, `contracts/`, `tools/`, `infra/`), even with one package, and a package is created with a skill, never by hand. See [STRUCTURE.md](shared/STRUCTURE.md)
- A workflow, primarily inspired by [Superpowers](https://github.com/obra/superpowers) and [Matt Pocock's skills](https://github.com/mattpocock/skills).
- The same set of git hooks run everywhere and are never disabled to make a commit pass.
- `INTENT.md`, the rule files under `.claude/rules/`, `CONCEPTS.md` and decision records carry purpose, principles, terms and decisions, in that division and no other.
- Agents apply named principles with judgment. The organization's principles come from the `principles` plugin and are never copied into a repository.
- Work is reviewed on its pull request, which the agent opens without asking; planned work is also reviewed at the plan. Not commit by commit.
- A pull request lands as one commit, with its title as the subject in Conventional Commits form and its body as the message under seven fixed headings; `check-pull-request` checks both, locally and in CI, and commits on the branch are free-form.
- A repository can override a baseline value with a comment saying why; it cannot opt out of the baseline.

## The pieces

- A Claude Code plugin marketplace: one plugin per concern, with in-house skills and vendored third-party skills side by side, plus pinned third-party plugins. Everything third-party was read by a named person at a recorded commit.
- A shared `devenv` module (`lyngon/devenv`) that gives every repository the same git hooks, MCP server file, languages and `check-pull-request` command, and the tools that the scripts of skills run.
- A set of shared documents behind both, in `shared/`.

Other kinds of reusable pieces may join; the test is that they are used by more than one repository.

Every third-party skill was read by a named person at a recorded commit before it got in.

## Intent

What this repository is for, for whom, and what done means is in [INTENT.md](INTENT.md).

## Layout

```text
.
├── .claude-plugin/
│   └── marketplace.json    the marketplace manifest
├── plugins/
│   ├── all/                the bundle every Lyngon repository installs
│   └── <concern>/          one plugin per concern, in-house and vendored skills side by side
│       ├── .claude-plugin/plugin.json
│       ├── LICENSE-<upstream>  link to the license of an upstream whose text the plugin holds
│       ├── evals/<case>/   an eval case: prompt.md, its graders and the files a run starts with
│       └── skills/<name>/  a skill, in-house or vendored
├── catalog/
│   ├── <plugin>.md         provenance record for every pinned third-party plugin
│   └── vendored/
│       └── <upstream>.md   provenance record for everything vendored from one upstream
├── shared/                 shared documents and upstream licenses, symlinked into the plugins that use them
├── devenv/                 the shared devenv module every Lyngon repository imports
├── scripts/                validation and generation run by git hooks and CI, and the eval comparison
├── .claude/
│   ├── CLAUDE.md           imports INTENT.md into every agent session
│   └── rules/              this repository's principles, one per file, loaded by path
├── docs/
│   ├── decisions/          decisions about this repository that the code cannot show
│   └── TODO.md             deferred work
├── INTENT.md               what the repository is for, for whom, and what done means
└── CONCEPTS.md             the terms used in this repository
```

## Flows

Which skills to invoke, in which order, for each kind of work, and where the human decides, is in [shared/WORKFLOW.md](shared/WORKFLOW.md).
In short: `/discover:brainstorm` writes nothing, `/discover:approach` settles a design and gates on approval, `/build:plan` turns it into tasks, `/build:delegate` or `/build:execute` builds them without asking, and `/build:finish` pushes the branch and opens its pull request for the second and last review.
The `practice` skills (`tdd`, `debug`, `verify`) and `review:receive` apply on their own in every flow.

## Plugins

Generated from the marketplace manifest by `scripts/render-plugin-list.sh`; do not edit between the markers.

<!-- plugins:start -->
| Plugin | Skills | Description |
| --- | --- | --- |
| `all` | bundle of `repo`, `discover`, `build`, `practice`, `review`, `writing`, `conventions`, `principles` | Every plugin a Lyngon repository uses, installed with one command. A bundle: it has no skills of its own. |
| `repo` | `/repo:add-package`, `/repo:init` | Set up or adopt a repository to Lyngon conventions (interview, INTENT.md, the agent file, README, CONCEPTS.md, decision records, devenv, git hooks) and create packages in the kind-first layout. |
| `discover` | `/discover:approach`, `/discover:brainstorm`, `/discover:domain-model`, `/discover:explanation`, `/discover:how`, `/discover:interview`, `/discover:why` | Discovery before building: toss ideas around without writing anything, sharpen a design with a relentless interview that writes CONCEPTS.md terms and decision records as they crystallise and gates implementation on approval, find out how code works and why it is the way it is, or have both explained plainly. |
| `build` | `/build:correction`, `/build:delegate`, `/build:execute`, `/build:finish`, `/build:plan` | From an approved design to an open pull request: a plan of test-first tasks, executed inline or with a fresh subagent per task, a ledger that survives compaction, a review after every task and a whole-branch review at the end. A correction is recorded in the mistake ledger, and a mistake that repeats becomes a check. |
| `practice` | `/practice:debug`, `/practice:tdd`, `/practice:verify` | Engineering discipline while changing code: test-driven development, systematic debugging and verification before any claim of done. Invoked by the agent on its own. |
| `review` | `/review:receive`, `/review:request` | Code review both ways: dispatch a reviewer subagent with a crafted brief and a commit range, and receive review feedback with technical rigour instead of performative agreement. |
| `devkit` | `/devkit:add-skill` | Maintain the Lyngon devkit itself: add third-party or new skills to the marketplace with vetting, provenance and placement by concern. |
| `writing` | `/writing:simpler`, `/writing:technical`, `/writing:unslop` | Prose quality: write technical documents to a standard that is understood on the first read, edit documentation, READMEs, posts and other non-code text so it reads as written by a person, and restate a message in plain words. |
| `conventions` | `decision-record` (agent-invoked), `documents` (agent-invoked), `engineering` (agent-invoked), `markdown` (agent-invoked), `nix` (agent-invoked), `python` (agent-invoked), `shell` (agent-invoked), `typescript` (agent-invoked) | Organization-wide conventions, invoked by the agent before it works: engineering rules for every change, one skill per language, and the rules for Markdown, decision records and the steering documents. |
| `principles` | `/principles:index` | The principles Lyngon agents apply with judgment: an index the agent reads before work that takes judgment, and one file per principle, vendored from pstack or written by Lyngon. |
| `skill-creator` | pinned, see [catalog/skill-creator.md](catalog/skill-creator.md) | Anthropic's skill authoring plugin: create, evaluate, improve and benchmark skills. Pinned; used by /devkit:add-skill to draft new in-house skills. |
<!-- plugins:end -->

## What a Lyngon repository looks like

A repository that adopts the structure is laid out by package kind, as defined in [shared/STRUCTURE.md](shared/STRUCTURE.md): entrypoints under `apps/`, libraries under `libs/`, cross-language interfaces under `contracts/`, repository-internal executables under `tools/`, and everything that references a deployable by coordinates under `infra/`.
Language is never a path segment.
A directory appears with its first package, so a one-package repository has `apps/<name>/` alone.
This is what `/repo:init` and `/repo:add-package` produce; the names are examples for one context, `orders`.

```text
my-service/
├── apps/
│   └── orders-api/             Python entrypoint: main, wiring, config; delivered as an image
│       ├── devenv.nix          tasks, hooks and processes for this package only
│       ├── README.md           what it is, how to run it
│       └── INTENT.md           only when its intent differs from the root's
├── libs/
│   ├── orders/                 core library: domain and application; holds CONCEPTS.md
│   └── orders-postgres/        one adapter per technology
├── contracts/
│   └── orders-api/             schema, one generated library per language, conformance/
├── infra/
│   ├── modules/orders-api/     how the deployable is instantiated
│   └── environments/prod/      one root per environment, never a branch
├── docs/
│   ├── decisions/              decisions the code cannot show, one file each, named after the decision
│   ├── conventions/            repository-specific conventions too long for a rule file
│   └── TODO.md                 work the owner explicitly deferred
├── .claude/
│   ├── CLAUDE.md               imports INTENT.md into every agent session
│   ├── rules/                  this repository's principles, one per file
│   └── settings.json           registers the lyngon marketplace, enables all@lyngon and each member
├── .github/workflows/
│   ├── ci.yml                  runs devenv test
│   └── pull-request.yml        runs check-pull-request on the title and the body of a pull request
├── .vscode/extensions.json     recommends the direnv extension
├── .envrc                      loads the devenv shell through direnv
├── pyproject.toml              the Python workspace: explicit members, one uv.lock
├── ruff.toml                   every stable ruff rule, each ignore with its reason
├── devenv.yaml                 imports lyngon/devenv and every package's devenv.nix
├── devenv.nix                  lyngon.enable and lyngon.structure.enable, languages, hooks and tasks
├── secretspec.toml             declared secrets; values never enter the repository
├── INTENT.md                   why and for whom
├── CONCEPTS.md                 the terms
└── README.md                   how to use
```

And the way of working in it, in the order things happen:

- `/repo:init` once, to set the repository up or bring an existing one onto the baseline; it writes the Lyngon documents, the baseline and the workflow, and asks whether the repository adopts the structure.
- `/repo:add-package` whenever a package is needed; it decides the directory from the package kind, writes the package files and registers the package in its workspace. Agents invoke it on their own.
- `/discover:approach` before building anything that has more than one reasonable design; terms land in CONCEPTS.md and decisions in decision records as they settle.
- A decision record only for a decision that passes the admission test in [DECISION-RECORD-FORMAT.md](shared/DECISION-RECORD-FORMAT.md), and only while the decision holds; a decision a check can carry becomes the check.
- `/discover:why` when a reason is needed: it answers from the decision records, the deleted ones included, and from git, pull requests and issues, and says what it found, what it inferred and what it could not find out.
- `/discover:how` when the question is how code works, and `/discover:explanation` to have a change or a subsystem explained plainly, from what `how` and `why` find.
- `principles:index` before work that takes judgment; the agent then reads the file of each principle that applies. A repository's own principles are its rule files under `.claude/rules/`.
- Conventions come from the `conventions` plugin, whose session hook and skill descriptions tell agents to invoke them before working: engineering rules for every change, one skill per language, and the rules for Markdown, decision records and the steering documents. Nothing is copied into the repository.
- `build:correction` when the operator corrects the agent, a review finding is accepted or a change is reverted. A first occurrence becomes a file in the mistake ledger, `docs/mistakes/`, and a mistake that repeats becomes a check, or a rule file when no tool can decide it.
- `/writing:technical` when a document, a pull request description or a commit message is written or reviewed, and `/writing:unslop` before any prose is handed over.
- `devenv test` before every push; it runs every git hook on every file, and no hook is ever disabled to make it pass.
- `check-pull-request` before a pull request is opened, and again in CI whenever its title, its body or its branch changes; a body over the limit is shortened, and the limit is never raised to let it pass.

## Installing the plugins

A Lyngon repository installs `all`, the bundle of every plugin for development, see the table above.
Its members assume a Lyngon development repository (Nix, devenv, the baseline, the documents and the workflow) and each other, so they are installed together and never as a subset.
Among them, `conventions` carries the workflow's standing instruction to commit, push and open pull requests without asking.
In the repository:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install all@lyngon --scope project
```

Any other repository installs `writing` alone.
It assumes nothing about the repository it is installed in and needs no other plugin:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install writing@lyngon --scope project
```

## Adopting a repository

The steps are the same for an empty repository and for one that has grown organically; `/repo:init` tells them apart by the tracked files.

1. Install `all` as above.
2. Open Claude Code in the repository and run `/repo:init`.
   It interviews you, then writes INTENT.md, `.claude/CLAUDE.md`, README.md, CONCEPTS.md, decision records, devenv with the shared module imported, git hooks, CI, every package you named when the repository adopts the structure, and a `.claude/settings.json` that registers the marketplace and enables `all@lyngon` and each of its members by name.
3. `/repo:init` commits its work: one root commit on `main` in a fresh repository, a branch with a pull request in an adopted one.

In an existing repository, init shows a diff for every file it would touch, merges into an existing README.md instead of replacing it, and sorts an older `CLAUDE.md`, `AGENTS.md` and `docs/adr/` into rule files and decision records before it deletes them.

Colleagues who clone the repository get the marketplace registered as soon as they trust the folder.
Plugins are not installed for them automatically (Claude Code 2.1.195 and later); Claude Code reports them as not installed and shows the command.
The settings name every plugin: Claude Code does not count a plugin installed with the bundle as enabled when it checks what another plugin depends on (seen in Claude Code 2.1.278), so the settings do not rely on the bundle to enable its members.
One command still installs them all:

```sh
claude plugin install all@lyngon --scope project
```

To add a plugin outside the bundle to an adopted repository, such as a pinned one, `--scope project` writes it into the committed settings:

```sh
claude plugin install skill-creator@lyngon --scope project
```

## Versions and updates

A plugin has no `version`, because the commit is the version.
Claude Code gives a plugin that declares none the first 12 characters of the marketplace's commit as its version, when the marketplace is served from git.
Every commit to the default branch is therefore a new version of every plugin, including a plugin the commit does not touch.
What a repository learns of an update is the commits under the plugin's path, one for each pull request, and a breaking change is the `!` in the title of its pull request.
In a clone of this repository:

```sh
git log --oneline -- plugins/build
```

Only a pinned third-party plugin has a `version`, in its marketplace entry.

## Developing

Every tool comes from the devenv shell.
The shell is built from `devenv/`, the same baseline module other Lyngon repositories import (see `devenv/devenv.nix` for the consumer snippet).

```sh
devenv allow
devenv shell
```

Automatic activation: either `direnv allow` (uses `.envrc`), or add `eval "$(devenv hook zsh)"` to your shell configuration and skip direnv.
The VS Code extension `mkhl.direnv` loads the same environment into the editor, but the Claude Code extension keeps the environment it started with.
The `repo` plugin's hooks export the current environment into each agent session and refresh it when the devenv files change.

Run every check the way CI does:

```sh
devenv test
```

Check the title and the body of a pull request the way CI does, with the body in a file such as `tmp/pull-request-body.md`:

```sh
PR_TITLE="feat(devenv): add a thing" PR_BODY="$(cat tmp/pull-request-body.md)" check-pull-request
```

It prints nothing when both pass.
The workflow `pull-request` runs the same command on every pull request.

This repository registers itself as the marketplace `lyngon` from the working tree in `.claude/settings.json`, so a Claude Code session opened here installs the plugins from this checkout. Project marketplaces are applied once per Claude Code process start, so a new registration needs a fresh session, not `/reload-plugins`.

### Evals

An eval case is a directory `plugins/<plugin>/evals/<case>/` that holds a `prompt.md` and its graders under `graders/`.
Which changes owe one is in [a-skill-change-owes-an-eval.md](.claude/rules/a-skill-change-owes-an-eval.md).
Evals run on the author's machine and never in CI, and every run is a model call on the author's account.
The command that runs them is documented at <https://code.claude.com/docs/en/plugin-evals>.

Run the suite of a checkout from its root:

```sh
claude plugin eval . --no-publish --ablation none --trust-plugin --scaffold --allow-tools Write
```

Without `--no-publish` the command publishes its report to claude.ai.
`--ablation none` leaves out the arm that runs without plugins, and `--trust-plugin` answers the question whether to trust the checkout.
`--scaffold` runs the script of each case that seeds its working directory, as you and outside the sandbox.
A case lists the tools it wants in `allowed_tools`.
A gated tool, such as `Write` or `Bash`, is removed from a run unless `--allow-tools` grants it, and a grant holds for every case of the run.
The report lands under `evals/results/`, which git ignores.

The target is the root because a case can only name plugins inside the target, and a case here names the plugins directory.
Its frontmatter line `plugins: ["../../.."]` loads every plugin under `plugins/` from the checkout, so a case of one plugin can use the skills of another.
A case of `writing` has no such line and runs with `writing` alone, which shows that `writing` needs no other plugin.
`validate-marketplace` fails a case that breaks either rule.

A run starts in an empty working directory.
A case that needs files there keeps them under `workspace/`, next to a `seed-workspace.sh` that copies them in and a `case.yaml` that names the script as `context.scaffold_script`.
Two cases that ask about the same files keep them once, and the script of the second copies the `workspace/` of the first.
The `case.yaml` holds `schema_version`, `name` and `context` and nothing else, since everything else of a case is in the frontmatter of `prompt.md`.
Its `name` is the name of the case's directory, and `validate-marketplace` fails another name and any other key.
`context.add_dirs` does not serve here: it lets a run read a directory of the case where it lies, and nothing tells the agent where that is (measured on Claude Code 2.1.283).

A case proves a change only when it scores the same in every run, so write it to leave the model little room:

- Invoke the skill as a slash command when the case is about what the skill does. A trigger phrase tests the routing, and another skill may answer.
- Grade no call of the Skill tool in such a case, since the harness loads a slash command itself.
- Say in the prompt what the workspace is. A run starts in an empty directory, and an agent that expects code there stops to ask where it is.
- Prefer a grader that no model judges.
- Leave to a judge only what no other grader can check. Whether a file was written is for `file_exists`. A rubric that also asked whether the reply announced one failed a reply that kept its list of ideas in chat, in 37 of 39 votes (measured on Claude Code 2.1.283).
- Grade the call that deletes a seeded file, not the file. A grader that targets a file that is gone fails whatever it looks for, and `file_exists` and the target `files` see only what the run created (measured on Claude Code 2.1.283).
- List `Write` in a case that expects no file, and grant it to the run. Without the grant the agent has no tool that creates a file, so the grader cannot fail. A run prints `not granted` for a case that lists a tool the run lacks, unless `--json` names a file for its result (measured on Claude Code 2.1.283), and `compare-evals` repeats that line below its table.
- Grade how a subagent was started on its `Agent` call. A `tool_used` grader counts the calls that subagents make too, at every depth.
- Grade that the agent ends one turn with the pattern `"type":"result"` and `match: "count:1"` on the target `trace`. The trace holds one such event for each turn the agent ends, and `last_message` holds the text of the last turn only (measured on Claude Code 2.1.283).
- When a judge's three votes agree and the score still moves between runs, the replies differ. Read a failing reply before changing the rubric.
- When the three votes of one run disagree, the rubric leaves the judge room. To find the clause, have the judge vote on that reply again, in a scratch case whose prompt asks the agent to repeat the reply word for word and whose graders are the clauses of the rubric, one each. Count only the runs whose `evidence` in the result is that reply, since the agent drops a line now and then.

Run the suite at a base commit and in the working tree, and print the score of each case at both:

```sh
compare-evals origin/main --allow-tools Write
```

`compare-evals` checks the base commit out into a temporary worktree, runs the command above in both places, the scripts that seed a working directory included, and removes what it created.
The working tree counts as head, uncommitted changes included.
In the table a dash stands for a case that the commit does not have.
Below the table each grader that failed is listed with the number of runs it failed in.
A run that the harness refused or cut short is counted as an error beside the score, and its reason is listed too.
So is every line that the harness printed about a case as a whole, in the harness's words.
That is how a comparison names a gated tool that a case lists and the run did not grant:

```text
plugins/discover/evals/brainstorm-no-docs at head: not granted (missing --allow-tools grant, or a malformed entry): Write
```

A grader that expects that something did not happen cannot fail in such a run, so the score of that case is no proof until the run grants the tool.
`compare-evals` finds such a line by the name of the case at its start and reads none of the words after it (measured on Claude Code 2.1.283).
When a later harness starts such a line otherwise, the line is missing below the table and still in the output of the run, which goes to stderr as it comes.
There the harness also says `kept temp` for the sandbox of a run that ended in an error, and `compare-evals` removes that sandbox with the rest.
A case that is new at head has no score at the base commit.
To see it fail first, commit the case before the change it proves and name that commit as the base.

While iterating, narrow both runs to one case, one run and a cheaper model:

```sh
compare-evals origin/main --allow-tools Write --case python-domain-value --runs 1 --model sonnet
```

A run that grants Bash puts every command under the sandbox of the harness, which must be able to exclude the credential stores of the machine.
Where it cannot, the harness refuses the run, with a message of these two parts:

```text
the AWS (~/.aws) credential store on this machine holds a symbolic link inside it, so the Bash sandbox cannot reliably exclude it
a Bash-granting evaluation cannot run here; keep the store's contents in one plain directory (its root may be a link)
```

So `~/.aws` must hold no symbolic link inside it.
A `~/.aws/config` that the machine's Nix configuration links into the store is one, and the fix belongs in that configuration.
The refusal is a safety check of the sandbox, so never work around it, for example by pointing `HOME` elsewhere.
When an eval cannot run, the pull request says so and makes no claim about the behaviour.

## Adding a plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json` with `name`, `description` and `license`, and without a `version`.
2. Add skills under `plugins/<name>/skills/<skill>/SKILL.md`.
3. Add an entry to `.claude-plugin/marketplace.json`, also without a `version`; the commit is the version, and the validator refuses the field in both files.
4. Add it to the `dependencies` of `plugins/all/`, unless its marketplace category is `devkit`.
5. Run `devenv test`; it regenerates the plugin table above and fails until the change is staged.

A member of `all` declares no `dependencies` of its own.
It assumes a Lyngon development repository and every other member, so its text names their skills as `<plugin>:<skill>`, and `validate-shipped-text` fails a name that no skill has.
What it says about the structure goes under a `With the Lyngon structure` heading, unless the plugin is `repo` or `devkit`.
Only a skill of `conventions` sets `user-invocable: false`.
A skill that must work outside a Lyngon development repository goes into `writing`, whose text names no other plugin's skill and no term of such a repository.

## Adding third-party work

Run `/devkit:add-skill <name, URL or description>` from a Claude Code session in this repository; it finds, vets and installs, and refuses upstreams without a license.
By hand, the same policy: read every skill, command, agent and hook you are about to take, then pick one of two kinds:

- **Pin the plugin** when the upstream plugin is used whole and unmodified: add a marketplace entry with a 40-character `sha` and a `version`, and a record in `catalog/<name>.md`.
- **Vendor the skill** when only some skills are wanted or they must be rewritten to Lyngon vocabulary: copy the skill into the plugin for its concern, record it in `catalog/vendored/<upstream>.md`, the one record for everything taken from that upstream, and link the upstream license from `shared/LICENSE-<upstream>` into the plugin's root.

See [catalog/README.md](catalog/README.md) for both.

## License

Apache-2.0 for everything Lyngon wrote.
Vendored text keeps the license of its upstream, which sits in `shared/LICENSE-<upstream>` and is linked into the root of every plugin that holds text from that upstream.
That includes the format documents in `shared/` adapted from mattpocock/skills, under MIT in `shared/LICENSE-mattpocock`.
The records under `catalog/vendored/` say which text came from which upstream.
