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
The devenv module under `devenv/` that every Lyngon repository imports: git hooks, the MCP server file, the `check-pull-request` command and the languages every repository has.

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

**Change**:
One concern, delivered as one pull request and landing on the default branch as one commit.
_Avoid_: task (that is an issue type), commit, PR

**Workflow**:
The way of working an owner adopts for a Lyngon repository: the agent follows the Lyngon conventions, commits each concern on a feature branch without asking, and pushes and opens a pull request once the full check passes; the owner reviews the pull request and decides the merge.
_Avoid_: process, flow (a flow is one path through the skills)

**Plan**:
The ordered tasks that turn an approved design into a finished branch, written for an implementer who knows the craft but not this repository.
_Avoid_: light plan, complete plan (there is one kind), spec

**Review gate**:
One of the two points where the owner reviews planned work: the design and the plan before execution, and the pull request after it.
_Avoid_: gate on its own, checkpoint

**Owner gate**:
A point in the execution of a plan where the executor stops until the owner decides: approves or performs one hard-to-reverse action, or answers a question the executor must not settle alone. The plan declares the ones it foresees; every stop it did not foresee is one too.
_Avoid_: gate on its own, approval step, hold point

**Pre-approval**:
The owner's explicit approval of one named owner gate, given when approving the plan, so that the executor passes that gate without stopping.
_Avoid_: blanket approval, standing approval

**Acceptance line**:
One behaviour a task must produce, stated in one line that can be checked on its own, with exact values where the design fixes them.
_Avoid_: requirement, test case, acceptance criteria for a single line

**Dictated text**:
Text a plan gives word for word because its wording is the decision: a decision record, a working rule, a term's definition, or text an agent follows as a procedure.
_Avoid_: verbatim block, copy text, boilerplate

**Mandated check**:
A command whose exact output a plan pins, shown failing when its property does not hold and passing when it does.
_Avoid_: verification step, smoke test

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
- A **Plan**'s execution lies between its two **Review gates**; its **Owner gates** lie inside it.
- A task of a **Plan** states the behaviour it leaves to its implementer as **Acceptance lines**; it has **Dictated text** only where the wording is the decision, and a **Mandated check** only where a command's exact output is the behaviour.
- An **Owner gate** has at most one **Pre-approval**, and only a gate whose action the executor performs can have one.
