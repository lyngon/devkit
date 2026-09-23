# Every Lyngon repository is laid out by package kind: apps, libs, contracts, tools, infra

The first layout was one flat `packages/` directory, one package per artifact.
It said nothing about what a package is, could not express the one dependency rule that matters (nothing imports an app), and had no home for infrastructure or cross-language interfaces.
We replace it with a layout by package kind, defined in `shared/STRUCTURE.md`: `apps/` for entrypoints, `libs/` for libraries, `contracts/` for schemas with their generated clients and conformance suites, `tools/` for repository-internal executables, `infra/` for everything that references deployables by coordinates, and `scripts/` for files that devenv runs.
A split is admitted only when it has a one-line membership test, a machine acts on it, and it is stable over the life of what it classifies; language fails the second test and is never a path segment.

## Considered options

- Flat `packages/`: one glob for every tool and no classification at creation time, but the kind of a package is invisible from its path and no dependency direction can be enforced by layout.
- `apps/` plus `packages/` (Turborepo): rejected because "package" is the generic unit in Python, npm, Cargo and Nix and in our own documents; using it for libraries only would conflict with every ecosystem.
- Language-first (`python/`, `typescript/`), or a language level under `libs/`: rejected because no rule or tool branches on language, the manifest already announces it, and a polyglot app has no correct place in such a tree.
- One package per onion layer: rejected as the default because it multiplies packages without buying enforcement the per-language lint does not already give; a layer becomes a package only when its dependencies must not leak into a consumer.
- Infra as apps and libs: rejected because infrastructure consumes deployables by registry coordinates, not packages by import, so it lives on a different plane with a different CI shape.

## Consequences

- Every package's kind is visible from its first path segment, and the validator in the baseline devenv module enforces the direction rules between kinds.
- A one-package repository has `apps/<name>/` alone; the asymmetry is accepted so every repository has the same path shape.
- Packages are created through `repo:add-package`, which encodes the decision procedure, so an agent never chooses a directory by guesswork.
- The devkit itself is exempt: it holds plugins and a devenv module, not packages.
- The vendored `domain-model` skill, the shared format documents and the `init` references were rewritten from `packages/<name>/` to the new paths.
