# Lyngon devkit

The terms used in this repository.
Definitions say what a thing is, not how it is implemented.

## Language

**Skill**:
A directory holding a `SKILL.md`, the unit of behavior an agent loads.
_Avoid_: command, prompt, recipe

**Plugin**:
A directory with a `.claude-plugin/plugin.json`, the unit of installation. Named after a concern and holding the skills for it, except a Bundle, whatever their origin.
_Avoid_: skill pack, extension

**Concern**:
The activity a plugin serves, such as setting up repositories or discovery before building. One plugin per concern.

**Bundle**:
A plugin with no skills of its own, which exists so that one command installs the plugins it depends on. `all` is the bundle.
_Avoid_: meta-plugin, pack, calling an ordinary plugin a bundle

**Devkit**:
This repository: the reusable pieces a Lyngon repository needs, today the marketplace, the baseline module and the shared documents.

**Marketplace**:
The part of the devkit described by `.claude-plugin/marketplace.json`, listing every plugin that can be installed from it.
_Avoid_: using "marketplace" for the whole repository

**Baseline**:
The devenv module under `devenv/` that every Lyngon repository imports: git hooks, the `check-pull-request` command, the tools of the scripts that skills ship, the languages every repository has, and the MCP server file for a repository that turns it on.

**In-house skill**:
A skill authored by Lyngon.

**Vendored skill**:
A skill copied from a third party into one of our plugins and rewritten to Lyngon vocabulary. The upstream license is in its plugin, and its provenance record is in the catalog.

**Pinned plugin**:
A third-party plugin listed in the marketplace at a fixed upstream commit. Nothing is copied.

**Catalog**:
The third-party part of the marketplace: every vendored skill and every pinned plugin.
_Avoid_: using "catalog" for the whole marketplace

**Provenance record**:
The file that documents what the catalog took from one upstream, at which commit, under which license, who reviewed it, where each piece went and which local patches it carries. `catalog/vendored/<upstream>.md` for vendored skills, `catalog/<plugin>.md` for a pinned plugin.
_Avoid_: catalog record, vetting note

**Vetted**:
The state of a catalog item whose text was read by a named person at the recorded commit.

**Package**:
A directory with its own manifest and declared dependencies, the unit of dependency in a Lyngon repository. Its kinds are App, Library, Contract and Tool.
_Avoid_: project, module, component

**App**:
A package whose artifact is run by a runtime. Holds main, wiring and config, and is depended on by nothing.
_Avoid_: service, application, executable

**Library**:
A package whose artifact is imported by other packages, inside or outside the repository.
_Avoid_: shared, common, package in the narrow sense

**Contract**:
A package holding the published boundary shape of an app, from which one library per consuming language is generated.
_Avoid_: interface package, shared model

**Tool**:
A package with an executable used only to develop or check its repository, never deployed or published.

**Script**:
A file under a `scripts/` directory that a devenv task or hook runs. Not a package.

**Artifact**:
An immutable build output of a package. A distributable when published under coordinates, a deployable when a platform can instantiate it.

**Structure**:
The layout, vocabulary and dependency rules a Lyngon repository follows when it has adopted them, defined in `shared/STRUCTURE.md`.
_Avoid_: monorepo, package layout

**Steering document**:
A document in the tree that states what the code cannot show and that an agent must follow: a repository's intent, principles, terms and decision records, and the organization's principles.
_Avoid_: standard document (that names the file set), governing document

**Decision record**:
A steering document stating one decision the code cannot show, named after the decision and kept only while the decision holds.
_Avoid_: ADR, architecture decision record

**Owner**:
A person accountable for a repository, who decides its direction, approves changes to its steering documents and decides what merges.
A repository may have several.
_Avoid_: maintainer, user

**Operator**:
The person who started the session an agent is working in.
An operator answers for the task at hand, and for the product only when they are also an owner.
_Avoid_: user, driver

**Principle**:
A named, binding statement that takes judgment to apply.
_Avoid_: guideline, best practice, convention

**Rule**:
A named, binding statement that a tool can decide.
Its name is the identifier its check reports.
_Avoid_: convention, hard rule, working rule

**Mistake ledger**:
The directory that holds one file per mistake an agent made in the repository for the first time, kept until the mistake repeats and gets a check, or ages out.
_Avoid_: rule table, lessons learned

**Change**:
One concern, delivered as one pull request and landing on the default branch as one commit.
_Avoid_: task (that is an issue type), commit, PR

**Workflow**:
The way of working in a Lyngon repository, where a prompt or an issue comes in, the agent decides and acts under the standing instructions, and proof and a pull request come out for the owner to review and merge.
_Avoid_: process, flow (a flow is one path through the skills)

**Standing instructions**:
The text every agent session in a Lyngon repository starts with, saying that it is a Lyngon repository, when to ask, how a change is branched, checked and handed over, and when to read the principles and record a mistake.
_Avoid_: baseline (that is the devenv module), system prompt

**Mode**:
A way of working that an operator switches on for one task by invoking a skill, and that adds routing, delegation and proof rules to the standing instructions.
_Avoid_: style, persona

**Playbook**:
A file of a mode that says, for one kind of task, what must hold when it is done and what proof is owed.
_Avoid_: recipe, procedure

**Gate**:
A point where an agent stops until the owner answers. One always holds, before an irreversible action and for a product or preference call that no run can settle. Any other exists only where the owner asked for it.
_Avoid_: checkpoint, approval step, hold point

**Proof**:
Something a reviewer can rerun or read that shows a claim holds.

## Relationships

- The **Devkit** holds the **Marketplace**, the **Baseline** and the shared documents.
- The **Marketplace** lists many **Plugins**; each **Plugin** that is not a **Bundle** serves one **Concern**.
- A **Plugin** that is not a **Bundle** holds one or more **Skills**, each either **In-house** or **Vendored**.
- A **Provenance record** covers one upstream at one commit: every **Vendored skill** taken from it, or one **Pinned plugin**.
- Every **Pinned plugin** has exactly one **Provenance record**, and every **Vendored skill** is in the record of each upstream whose text it holds.
- A **Pinned plugin** is never **Vendored**, and a **Vendored skill** never comes from a **Pinned plugin**.
- The **Structure** is one of the shared documents; the **Baseline** enforces its dependency rules.
- A **Package** is exactly one of **App**, **Library**, **Contract** or **Tool**; a **Script** is never a **Package**.
- An **Owner** approves every change to a **Steering document** of their repository.
- An **Owner** may act as an **Operator**; an **Operator** need not be an **Owner**.
- A mistake in the **Mistake ledger** that repeats becomes a **Rule** with its check, or a **Principle** when no tool can decide it.
- The **Standing instructions** reach every session, and a **Mode** reaches only a session whose **Operator** switched it on, where it adds to them.
- A **Mode** has one **Playbook** for each kind of task it routes.
- A **Gate** that is not the one that always holds exists only where an **Owner** asked for it.
- A **Change** carries the **Proof** of what it claims in its pull request.
