# Lyngon devkit

The terms used in this repository.
Definitions say what a thing is, not how it is implemented.

## Language

**Skill**:
A directory holding a `SKILL.md`, the unit of behavior an agent loads.
_Avoid_: command, prompt, recipe

**Plugin**:
A directory with a `.claude-plugin/plugin.json`, the unit of installation. Named after a concern and holding the skills for it, whatever their origin.
_Avoid_: skill pack, extension, bundle

**Concern**:
The activity a plugin serves, such as setting up repositories or discovery before building. One plugin per concern.

**Devkit**:
This repository: the reusable pieces a Lyngon repository needs, today the marketplace, the baseline module and the convention documents.

**Marketplace**:
The part of the devkit described by `.claude-plugin/marketplace.json`, listing every plugin that can be installed from it.
_Avoid_: using "marketplace" for the whole repository

**Baseline**:
The devenv module under `devenv/` that every Lyngon repository imports: git hooks, the MCP server file and the languages every repository has.

**In-house skill**:
A skill authored by Lyngon.

**Vendored skill**:
A skill copied from a third party into one of our plugins, rewritten to Lyngon vocabulary, with the upstream license and a provenance record beside it.

**Pinned plugin**:
A third-party plugin listed in the marketplace at a fixed upstream commit. Nothing is copied.

**Catalog**:
The third-party part of the marketplace: every vendored skill and every pinned plugin.
_Avoid_: using "catalog" for the whole marketplace

**Provenance record**:
The file that documents where a catalog item came from, at which commit, under which license, who reviewed it, and which local patches it carries. `UPSTREAM.md` for a vendored skill, `catalog/<plugin>.md` for a pinned plugin.
_Avoid_: catalog record, vetting note

**Vetted**:
The state of a catalog item whose text was read by a named person at the recorded commit.

## Relationships

- The **Devkit** holds the **Marketplace**, the **Baseline** and the shared convention documents.
- The **Marketplace** lists many **Plugins**; each **Plugin** serves one **Concern**.
- A **Plugin** holds one or more **Skills**, each either **In-house** or **Vendored**.
- Every **Vendored skill** and every **Pinned plugin** has exactly one **Provenance record**.
- A **Pinned plugin** is never **Vendored**, and a **Vendored skill** never comes from a **Pinned plugin**.
