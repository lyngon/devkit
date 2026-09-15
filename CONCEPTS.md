# Lyngon skills

The terms used in this repository.
Definitions say what a thing is, not how it is implemented.

## Language

**Skill**:
A directory holding a `SKILL.md`, the unit of behavior an agent loads.
_Avoid_: command, prompt, recipe

**Plugin**:
A directory with a `.claude-plugin/plugin.json`, the unit of installation. Holds one or more skills, and possibly commands, agents and hooks.
_Avoid_: skill pack, extension, bundle

**Marketplace**:
This repository as a whole, described by `.claude-plugin/marketplace.json`, listing every plugin that can be installed from it.

**In-house plugin**:
A plugin authored by Lyngon, living under `plugins/`.

**Catalog**:
The subset of the marketplace made of third-party plugins, each backed by a catalog record.
_Avoid_: using "catalog" for the whole marketplace

**Catalog entry**:
A third-party plugin listed in the marketplace, either pinned or vendored.

**Catalog record**:
The Markdown file under `catalog/` that documents who reviewed a catalog entry, at which upstream commit, under which license, and with which local patches.
_Avoid_: provenance file, vetting note

**Pinned**:
A catalog entry whose marketplace source points at the upstream repository at a fixed commit. Nothing is copied.

**Vendored**:
A catalog entry whose files are copied into `plugins/third-party/`, together with the upstream license.

**Vetted**:
The state of a catalog entry whose listed skills, commands, agents and hooks were read by a named person at the recorded commit.

## Relationships

- A **Marketplace** lists many **Plugins**.
- A **Plugin** holds one or more **Skills**.
- Every **Catalog entry** has exactly one **Catalog record**.
- A **Catalog entry** is either **Pinned** or **Vendored**, never both.
