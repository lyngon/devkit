---
name: add-package
description: Create a package in a Lyngon repository in the directory its kind decides (apps/, libs/, contracts/, tools/, infra/), with INTENT.md, README.md, CLAUDE.md, devenv.nix and the layer lint, and register it in its workspace and devenv. Use whenever a new app, service, CLI, library, adapter, contract, schema, tool, infra module or environment is needed, including when one feature needs several packages. Never create a package by hand.
argument-hint: "[kind] [name]"
---

# Add a package

## Overview

One package, in the right place, with the right files, registered everywhere it must be.
The rules come from [STRUCTURE.md](STRUCTURE.md); this skill is the decision procedure so you never choose a directory by guesswork.
Agents invoke it on their own: a feature that needs a core library, an adapter and an app runs it three times.

## When to use

- Any new package: app, library, adapter, contract, tool, infra module or environment.
- Splitting a layer out of an existing package because its dependencies leak.
- Bringing a package that was created by hand onto the structure.

## When not to use

- Adding a module inside an existing package. That is a file, not a package.
- A repository whose root `CLAUDE.md` does not say "This repository follows the Lyngon structure". Stop and say that the structure has not been adopted; `repo:init` adopts it. Never create the layout on your own in such a repository.

## Workflow

### 1. Read the repository

Read the root `CLAUDE.md`, `CONCEPTS.md` and, if it exists, the `CONCEPTS.md` of the context the package belongs to.
List the existing packages under `apps/`, `libs/`, `contracts/`, `tools/` and `infra/`, and the workspace files at the root (`pyproject.toml`, `pnpm-workspace.yaml`, `Cargo.toml`, `go.work`).
Read `STRUCTURE.md` sections 3 and 4 if you have not this session.

### 2. Decide kind, context and name

Apply the tests in order; the first that matches is the kind.

| Kind | Test | Path |
| --- | --- | --- |
| Environment | One instantiation of the system with its own state and account | `infra/environments/<env>/` |
| Infra module | Instantiates one deployable of this repository, or is a reusable HCL module | `infra/modules/<name>/` |
| Contract | The boundary shape of an app, consumed by another language or another system | `contracts/<name>/` |
| Tool | An executable used only to develop or check this repository; never deployed or published | `tools/<name>/` |
| App | Nothing depends on it; a runtime runs it | `apps/<ctx>-<name>/` |
| Core library | Holds a context's domain and application | `libs/<ctx>/` |
| Adapter | Implements a port of a context against one technology | `libs/<ctx>-<tech>/` |
| Library | Imported by others and fits none of the above (a construct library, a shared toolkit) | `libs/<ctx>-<name>/` |

Then:

- The context prefix is the bounded context the package serves. A new context starts with its core library; an adapter or app never precedes it, unless the app only composes existing libraries.
- Names are kebab-case. An app's name says what it is for a person (`orders-api`, `orders-worker`, `orders-web`, `orders-cli`); an app backing several runtime units takes a name that covers them (`orders-backend`).
- A library that would also ship an executable is two packages: the library and a thin app.
- A generic CDK construct library goes to `libs/`; a construct that wires one of this repository's apps goes to `infra/modules/`.

State kind, path and name in one line before writing anything.
Ask only when two kinds fit and the answer changes the path.

### 3. Create the manifest

Inside the devenv shell, with the stack's own initializer, never by hand:

```sh
uv init --lib libs/orders --name orders            # Python library
uv init --app --package apps/orders-api            # Python app
pnpm init                                          # in the package directory
cargo new --lib libs/orders                        # or --bin for an app
go mod init github.com/lyngon/<repo>/apps/orders-cli
```

Remove any lockfile or virtual environment the initializer created inside the package; the workspace at the root owns them.
A library manifest declares constraints (`foo>=3.14`), never pins.

### 4. Register the package

- Add the path to the language's workspace member list at the root, explicitly, never as a glob. Create the workspace file if it is the first package of that language, following [references/workspaces.md](references/workspaces.md).
- Add `./<path>` to `imports` in the root `devenv.yaml`.
- Add one line for the package under `## Layout` in the root `CLAUDE.md`.
- For a new context, add it to the root `CONCEPTS.md` map, or convert the root file into a map when this is the second context (see the `discover:domain-model` skill).
- For a Python or TypeScript package, run the workspace sync (`uv sync`, `pnpm install`) so the lockfile records it.

### 5. Write the package files

Templates are in [references/package-files.md](references/package-files.md).

- `devenv.nix`: the package's tasks, hooks scoped with `files`, and processes. No `languages.*`; languages are enabled at the root.
- `README.md`: what it is and how to run it.
- `INTENT.md`: why it exists and for whom. For an app, the product section states the deployable kind and the runtime units it backs.
- `CLAUDE.md` with only what differs from the root, and `AGENTS.md` as a symlink to it.
- `docs/adr/`: not created until the first decision.

By kind:

- **Core library**: `domain/` and `application/` as modules, `CONCEPTS.md` from the terms settled so far, and the layer lint from [references/layers.md](references/layers.md).
- **Adapter**: depends on its core library; nothing in it is imported by the core.
- **App**: main, wiring and config only. When the deployable is an image, a `Dockerfile` or `dockerTools` derivation in the package. Local development runs from source through a devenv process, never through the image.
- **Contract**: the schema, one generated library package per consuming language, the freshness hook, and the `conformance/` package, following [references/contracts.md](references/contracts.md).
- **Tool**: an executable target; may depend on anything.
- **Infra module**: references the deployable by coordinates; mirrors the app's name.
- **Environment**: its own state backend and variables; instantiates modules; never a branch.

### 6. Verify

```sh
devenv test
```

The baseline `validate-structure` hook checks the dependency rules, the member lists and the file set.
Fix what fails without disabling a hook.
Report the result faithfully.

### 7. Hand-off

Do not commit and do not stage.
List the files written and the registrations made, and offer the commit message `feat(<name>): add <kind> <name>`.
When the package is an app that will be deployed, say that `infra/modules/<name>/` is the next package to add once the deployment target is known.
