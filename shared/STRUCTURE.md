# Repository structure

The layout, vocabulary and dependency rules of every Lyngon repository.
Single source in `shared/` of the Lyngon devkit; plugins symlink it.
Section 2 defines terms, which describe.
Sections 3 and 4 state policies, which constrain.
The two are kept apart on purpose: "a package builds one artifact" is a policy, and false as a definition.

The devkit itself is the one repository that does not follow this layout: it ships plugins, a devenv module and convention documents, not packages.

## 1. When a rule earns a place in the tree

A directory split is a classification, and every classification costs a decision at creation time and a move when the classification changes.
A split earns its place only when all three hold:

1. **It has a one-line test** that decides membership without judgement. "Nothing depends on it" decides App.
2. **A machine acts on it**: a dependency direction the validator checks, a CI scope, a publishing step, a different toolchain. A split no tool branches on is decoration and drifts.
3. **It is stable** over the life of the thing it classifies.

Language passes the third test and fails the second.
No dependency rule and no CI step depends on the language a package is written in, and a polyglot app has no correct place in a language-first tree.
Kind (run or import) passes all three.
Everything in section 4 was admitted by this test, and anything proposed later must pass it too.

Agents differ from people in three ways that matter here.
An agent pays the learning cost of the layout every session, so legibility from the tree and one `CLAUDE.md` is worth more than it is for people.
An agent drifts the way a junior does, and only a mechanical check reaches it, so every rule below is also a check.
An agent does mechanical multi-file work cheaply, so finer packages than a human team would choose are affordable, as long as each package has a reason to exist.

## 2. Terms

Every language ecosystem collapses four axes into one or two overloaded words: source organisation, the build and dependency unit, the build output, and the runtime unit.
This vocabulary assigns one term per concept per axis.
Language-specific terms are mapped onto it in section 5, never used in its place.

### 2.1 Source and build

| Term | Definition | Test |
| --- | --- | --- |
| **Repository** | The version-control root. Holds one workspace per language and the repository-level tooling (devenv, CI). | One VCS history. |
| **Workspace** | One language tool's grouping of that language's packages, resolved and built together under one lockfile. Never the repository, never an editor window. | One lockfile, one toolchain. |
| **Package** | The smallest unit with its own manifest: name, declared dependencies, and a version when published. The unit of dependency. Kinds: App, Library, Contract, Tool. | Something else can depend on it by name. |
| **App** (package kind) | A package whose target is an Executable: its artifact is run by a runtime (OCI runtime, browser, shell, function host). Holds main, wiring and config, nothing else. | Nothing depends on it. |
| **Library** (package kind) | A package whose target is a Library: its artifact is imported or linked by other packages, inside or outside the repository. | Never runs on its own. |
| **Contract** (package kind) | The published boundary shape of an app: an IDL or schema from which one library per consuming language is generated. | Consumed by outer layers on both sides, never by a domain. |
| **Tool** (package kind) | A package with an Executable target used only to develop or check this repository. | Never deployed, never published. |
| **Target** | One buildable output declared by a package. Kinds: Library (importable, no entry point), Executable (entry point), Test. | The build tool can build it on its own. |
| **Module** | A named namespace or visibility unit inside a package. No version, no dependency list of its own. | You cannot depend on it at a version. |
| **Script** | A file under a `scripts/` directory that a devenv task or hook runs. Not a package: no manifest, no artifact. | Never imported. |
| **Layer** | One ring of the onion inside a context: domain, application, adapter, entrypoint (section 3.2). | Dependencies point inward only. |
| **Context** | A bounded context: one domain model, one glossary, one core library. Its packages share a name prefix. | One `CONCEPTS.md`. |

### 2.2 Output

| Term | Definition |
| --- | --- |
| **Artifact** | An immutable, identifiable file or file set produced by building a target. The roles below are not exclusive. |
| **Distributable** (role) | An artifact published under coordinates (name, version) for consumption by other builds. |
| **Deployable** (role) | An artifact a runtime platform can instantiate: OCI image, function package, static binary, web bundle, Nix closure. |
| **Registry** | Where distributables and deployables are published to and resolved from. |

One target yields many artifacts.
An artifact is determined by the target at a source revision, the platform and the build configuration, given the resolved dependencies and the toolchain version.
Examples: one Rust target per target triple, one Python build emitting an sdist plus a wheel per platform tag, a multi-arch OCI index pointing at per-arch images, debug and release profiles.
Signatures, SBOMs and provenance attach to artifacts by digest, never to packages or targets.

A **bundled** artifact has its dependencies closed over: fat JAR, JS bundle, statically linked binary, OCI image, Nix closure.
It hides its dependency graph from scanners and can only be patched by rebuilding, so every bundled deployable gets an SBOM generated at build time.

The **deployable kind** is decided by which platform instantiates the artifact.
A container runtime instantiates an image, a browser instantiates a web bundle, a shell instantiates a binary, a function host instantiates a function package.
Server versus function is decided by who owns the process lifecycle: a server owns its process and listens or polls until stopped; a function exposes a handler the platform calls per event.

### 2.3 Runtime

Aligned with C4.

| Term | Definition | Test |
| --- | --- | --- |
| **System** | A set of runtime units and data stores delivering one capability under one ownership boundary. | Has an owner and an external contract. |
| **Runtime unit** | What runs: **Service** (long-running, network interface), **Job** (runs to completion), **Client** (browser, mobile, desktop), **CLI** (invoked from a shell). Deployment concepts, never package kinds. | Can be started, stopped and scaled on its own. |
| **Data store** | Database, bucket, queue, topic. | Holds state and executes none of your code. |
| **Component** | A cohesive group of functionality behind an interface. A design concept, never independently deployable. | You draw it on a diagram. |
| **Environment** | One instantiation of a system: dev, staging, prod. A directory under `infra/environments/`, never a branch. | Has its own state and its own account. |

One app can back several runtime units: the same deployable run as `api` (Service) and `worker` (Job) with different commands is one App, one deployable and two runtime units.
The runtime units are defined in infra, because the app cannot know how many it becomes.

### 2.4 Relations

```text
Repository 1-n Workspace 1-n Package 1-n Target --build(platform, config)--> 1-n Artifact --publish--> Registry
                                                                                  |
runtime unit <--instantiates-- Deployable <---------------------------------------+
(Service | Job | Client | CLI)

App 1-n runtime unit
Context 1 core Library, 0-n adapter Libraries, 0-n Apps, 0-n Contracts
```

Invariants:

- A target belongs to exactly one package.
- A Library never exists at runtime as its own unit; it is always linked or imported into an App.
- Every runtime unit is instantiated from exactly one Deployable, built from exactly one App.
- Infra depends on deployables by coordinates, never on packages by import.

## 3. Policies

### 3.1 One non-test target per package

Each package declares exactly one Library or Executable target, plus any Test targets.
This is what makes App and Library well-defined package kinds.
An App is therefore a thin composition root (main, wiring, config) depending on Library packages that hold the logic, where it is testable and reusable.
The cost is that the idiomatic single Cargo package with a `lib` and a `bin`, and the Go `cmd/` plus `internal/` layout, are split into an app and a library.
No language gets an exception; one idiom exception per language multiplies into five.

### 3.2 Layers

Four layers, dependencies pointing inward only:

1. **domain**: the model and the rules on it. Depends on no other layer.
2. **application**: use cases and ports. Depends on domain.
3. **adapter**: one implementation of a port against one technology. Depends on application and domain.
4. **entrypoint**: main, wiring, config. Depends on everything and is depended on by nothing.

Domain model and domain logic are modules inside the domain layer, not separate layers.
Neither domain nor application ever imports a contract, a generated client, an adapter or an app.

### 3.3 The shape of a context

A context is by default three package shapes:

- `libs/<ctx>/`: the core library. Domain and application as modules, with a per-language lint enforcing the direction between them. Holds the context's `CONCEPTS.md` and `docs/adr/`.
- `libs/<ctx>-<tech>/`: one adapter per package (`orders-postgres`, `orders-sqs`).
- `apps/<ctx>-<name>/`: one entrypoint per deployable.

A layer becomes its own package for one reason, that its dependencies must not leak.
In Python and TypeScript, importing the domain of a package pulls the whole package's third-party dependencies into the consumer, so heavy adapters (database drivers, cloud SDKs) are separate packages and the core stays pure.
Domain and application stay together until a consumer needs one without the other.
Consumer count alone is never a reason to split: a library with two consuming apps is the normal case.

### 3.4 Contracts

A contract is the published boundary shape of an app: DTOs, not domain objects.
Sharing a domain model across services is the shared-kernel trap; a contract is the anti-corruption boundary instead.
It is consumed by the provider's entrypoint (generated server stubs) and the consumer's adapter (generated client), never by a domain or application layer.

A contract directory holds the schema as the source of truth, one generated library package per consuming language, and one handwritten `conformance/` package.
Generated code is committed, and a hook in the contract's `devenv.nix` regenerates it and fails the commit when the result differs, so it stays visible to agents and editors without a bootstrap step and contract changes show their effect in review.
The generated library includes both client and server-side stubs, so the two sides cannot disagree.

The conformance package holds the invariants the schema cannot express (a returned id is valid for the other operations, create creates), written once against the generated client interface, as a library with a thin executable wrapper that points the generated client at a base URL.
The contract never starts a provider.
Each provider's test target starts itself and hands its URL, or an in-process client, to the suite.
A provider in another language runs the wrapper over the wire from its devenv test task.
Conformance is the single definition of "implements this contract".

### 3.5 Infra is a separate plane

`apps/` and `libs/` classify the build graph: packages that depend on each other through workspace tooling.
Infrastructure consumes deployables by registry coordinates (an image digest, a version) and is never imported, so it lives outside that graph.

- The deployable is built by the app: a Dockerfile or `dockerTools` in the app package. An OCI image is the executable target built for the OCI platform, not a second target.
- Everything that references a deployable by coordinates lives under `infra/`, including the per-app module. An app package contains no cloud knowledge. The co-change cost (a new environment variable touches `apps/orders-api` and `infra/modules/orders-api`) is paid for with mirrored names.
- `infra/modules/<name>/` holds one module per deployable, mirroring `apps/`, plus reusable modules. An HCL module has no manifest and belongs to no workspace, which is why it is not a Library.
- A CDK construct is a package in a language workspace, so the Library rules apply: a generic construct is `libs/<name>-constructs`, published or not; a construct that wires one of this repository's apps is `infra/modules/<name>`, as a workspace member.
- `infra/environments/<env>/` holds one root per environment, each with its own state backend and variables, all instantiating the same modules. Promotion is a change to the pinned coordinates in that directory. Environment branches are forbidden: they make production drift from main.
- Local development runs the app from source through devenv processes and services in the app's `devenv.nix`, never through the image.

### 3.6 One workspace per language, one version of everything

Each language has one workspace at the repository root with one lockfile: `pyproject.toml` and `uv.lock`, `pnpm-workspace.yaml` and `pnpm-lock.yaml`, `Cargo.toml` and `Cargo.lock`, `go.work`.
Members are listed explicitly, never by glob: a glob matches other languages' directories, and an explicit list makes adding a package a reviewable diff.
Members may live under `apps/`, `libs/`, `contracts/`, `tools/` and `infra/`.
Language servers and agents then see one interpreter and one `node_modules`, CI gets one cache key per language, and an internal library import is a plain workspace dependency.

A library's manifest declares constraints (`foo>=3.14`), never pins.
The lockfile pins for this repository's deployables.
A published library ships its constraints only; its external consumers resolve their own.
Infra never resolves dependencies: it references the finished deployable by digest.

Two libraries needing different versions of one dependency is a resolution failure that forces the upgrade.
That is the point. There is one true version of every dependency, third-party or internal.

Per-package `devenv.nix` files hold tasks, hooks and processes scoped to that package.
Languages are enabled once, at the root.

### 3.7 Versioning and release

- An internal library carries no version. Consumers use HEAD, and a breaking change updates every consumer in the same commit.
- A published library carries semver and a `CHANGELOG.md`, and has a consumer test: the built distributable installed into a clean environment and its public API exercised, which catches packaging errors unit tests cannot.
- An app is identified by its deployable's digest and a git tag at release.
- Only an external consumer justifies an independent release cadence, because only an external consumer cannot be updated atomically.

### 3.8 Tests

- Unit and integration tests live in the package they test.
- End-to-end tests (a runtime unit exercised through its external interface) live in the app that owns the user-facing behaviour, and become a tool of their own only when they span apps or need their own toolchain.
- Conformance tests live with the contract (section 3.4).
- Consumer tests live with the published library (section 3.7).

### 3.9 CI

A Nix cache makes unchanged builds free, but tests run as devenv tasks, not derivations, so CI filters by path.
Every package's path prefix is its CI unit.
Under the single-version policy CI must be dependency-aware: a change to a library runs the tests of every package that depends on it, not only the changed one.

### 3.10 The repository boundary

A repository is the unit of atomic change: one owner, one release train.
Anything that must change atomically together stays in; anything a different team must change without coordinating with this one is out.
Size is handled by the layout, never by splitting the repository.

## 4. Layout

```text
.
├── apps/<ctx>-<name>/           entrypoints, one Executable target each
├── libs/<ctx>/                  core library of a context: domain and application
├── libs/<ctx>-<tech>/           one adapter per package
├── contracts/<name>/            schema, one generated library per language, conformance/
├── tools/<name>/                repository-internal executables, never deployed
├── infra/
│   ├── modules/<name>/          how one deployable is instantiated; mirrors apps/
│   └── environments/<env>/      one root per environment, never a branch
├── scripts/                     files run by devenv tasks and hooks, no manifest
├── docs/adr/                    decisions about the whole repository
├── pyproject.toml  uv.lock      Python workspace, explicit members
├── pnpm-workspace.yaml  pnpm-lock.yaml
├── Cargo.toml  Cargo.lock
├── go.work
├── devenv.yaml  devenv.nix      imports lyngon/devenv and every package's devenv.nix
├── INTENT.md  CLAUDE.md  CONCEPTS.md  README.md
```

Directories appear when their first package does.
A one-package repository has `apps/<name>/` alone and nothing else; the asymmetry is accepted because every repository has the same path shape.

### 4.1 Rules per directory

| Directory | May depend on | Depended on by |
| --- | --- | --- |
| `apps/` | libs, contracts | nothing |
| `libs/` | libs, contracts | apps, libs, tools, infra |
| `contracts/` | nothing internal | apps (entrypoint), libs (adapters), tools |
| `tools/` | anything | nothing deployed or published |
| `infra/` | libs (constructs), deployables by coordinates | nothing |
| `scripts/` | nothing | devenv tasks and hooks only |

Language is an attribute of a package, never a path segment.
The one exception is `contracts/<name>/<language>/`, because one contract genuinely yields one package per language.

### 4.2 Naming

- Every package name is kebab-case and starts with its context prefix: `orders`, `orders-postgres`, `orders-api`.
- An app's name after the prefix says what it is for a person: `orders-api`, `orders-worker`, `orders-web`, `orders-cli`. An app backing several runtime units takes a name that covers them: `orders-backend`.
- The deployable kind is not in the name; it is evident from the build files and stated in the app's `INTENT.md`.
- A directory named `generated/` holds generated code and `vendor/` holds copied third-party code, so linters, coverage and agents skip them.

### 4.3 Package files

Every app and library holds:

- the language manifest, created with the stack's own initializer;
- `devenv.nix`, with the package's tasks, hooks and processes, imported from the root `devenv.yaml`;
- `README.md`: what it is and how to run it;
- `INTENT.md`: why it exists and for whom, in the same shape as the repository's;
- `CLAUDE.md`, with `AGENTS.md` symlinked to it, holding only what differs from the root;
- `docs/adr/`, created lazily;
- `scripts/`, optional, run through the package's devenv tasks.

The core library of a context also holds `CONCEPTS.md`.
The root `CLAUDE.md` names every package in one line each and points at the `repo:add-package` skill for creating one.

### 4.4 What is enforced

A repository that has adopted the structure says "This repository follows the Lyngon structure" in its root `CLAUDE.md` and sets `lyngon.structure.enable = true` in `devenv.nix`; the sentence is what agents and the session hook look for, the option is what enables the hook.
The baseline validator (`validate-structure` in the Lyngon devenv module) then fails the commit when:

1. anything depends on an app;
2. anything under `apps/`, `libs/` or `contracts/` depends on anything under `tools/` or `infra/`;
3. a package directory is missing from its language's workspace member list, a member is listed that does not exist, or a member list uses a glob;
4. an app or library lacks `README.md`, `INTENT.md`, `CLAUDE.md` or the `AGENTS.md` symlink;
5. a path segment under `apps/`, `libs/` or `tools/` is a language name.

The per-language lint in a core library (import-linter for Python, dependency-cruiser for TypeScript, crate boundaries for Rust) fails when domain imports another layer, application imports anything but domain, or either imports a contract, an adapter or an app.
The `repo:add-package` skill writes that configuration.
A contract's freshness hook fails when committed generated code differs from the schema.

## 5. Language mapping

| | Workspace | Package | Target | Module | Distributable, Registry |
| --- | --- | --- | --- | --- | --- |
| **Python** | uv workspace | project, "distribution package" (`pyproject.toml`) | `[project.scripts]`, else implicit | module (`.py`) and import package (directory) | sdist, wheel; PyPI |
| **TypeScript** | pnpm workspace | npm package | implicit: `exports`, `bin`; tsconfig project | ES module (a file) | `.tgz` of compiled JS and `.d.ts`; npm |
| **Rust** | Cargo workspace | Cargo package | crate (lib, bin, test, bench) | `mod` | `.crate` source tarball; crates.io |
| **Go** | `go.work` | Go module (`go.mod`) | `package main` is the Executable | Go package | tagged source zip; VCS and proxy.golang.org |
| **Haskell** | project (`cabal.project`, `stack.yaml`) | Cabal package | component (library, executable, test-suite) | `module` | sdist; Hackage |
| **Java** | Maven reactor, Gradle multi-project | Maven module, Gradle project | 1:1 (`packaging`) | Java `package`; JPMS module as export boundary | Maven artifact (GAV); Maven Central |
| **C#** | Solution (`.sln`) | Project (`.csproj`) | 1:1 with project (`OutputType`) | namespace (weak) | NuGet package; nuget.org |
| **C, C++** | none; CMake superbuild, Meson subprojects | none native; CMake `project()`, Conan recipe | CMake target | C++20 `module`; otherwise `.c` and `.h` by convention | source tarball, deb, rpm, Conan; no canonical registry |
| **Terraform** | none | none; a module directory | root module (runnable), child module (importable) | none | module archive; a module registry |

Nix is not a row: it is repository-level composition across all workspaces.
One derivation per target; derivation outputs are artifacts; a store path in a binary cache is a distributable; a closure is a bundled deployable.

## 6. Counter-intuitive mappings

- **Go**: the two core words are inverted. A Go module is the universal Package; a Go package is the universal Module. The major version lives in the import path (`/v2`). Executables are statically linked, hence always bundled.
- **Java**: a Java `package` is a Module; a Maven module is a Package. A Maven artifact is the universal Distributable, narrower than Artifact here.
- **Python**: an import package (directory with `__init__.py`) is a Module; the universal Package is the project. The distribution name is unrelated to the import name (`pillow` installs as `PIL`). Visibility is by convention only. No native Deployable; in practice an OCI image.
- **C#**: the Project (`.csproj`) is the Package; a NuGet package is the Distributable. An MSBuild target is a build step, not a Target. The real visibility boundary is the assembly.
- **Haskell**: Cabal's component means Target, colliding with C4 Component. `cabal.project` calls the Workspace a project. Hackage revisions can change a published package's bounds without a version bump; pin through Nix.
- **Rust**: a crate is a Target, but colloquially means Package. A package may have one library crate plus binary crates; policy 3.1 narrows this to one. Libraries are distributed as source, so every executable is bundled; generate an SBOM with `cargo-auditable`.
- **TypeScript**: a module is a single file; the only boundary above file level is the `exports` map. The distributable contains compiled JS, not TS. Install scripts execute code at dependency resolution time.
- **C and C++**: no Package concept at all. "Library" natively names an artifact (`.a`, `.so`), not a source-level unit. Headers are part of the distributable.

## 7. Word rules

Banned:

| Word | Problem | Say instead |
| --- | --- | --- |
| project | Package (C#, Python, Gradle), Workspace (Haskell), compile unit (TS), build root (CMake) | Package, Workspace or Repository |
| monorepo | Every Lyngon repository has this layout, so the word adds nothing and misleads with one package | Repository |
| container | C4 meaning versus OCI meaning | Allowed only for OCI. Otherwise Service, Job, Client, CLI, or Data store |
| bundle (noun) | JS bundle, OSGi, macOS `.app` | "bundled artifact" |
| application | Near-homonym of App, blurs build and runtime layers | App for the package; Service, Job, Client, CLI for what runs |
| shared, common | Say nothing about kind | Library |
| infrastructure (as a layer) | Names where a thing sits, not what it is | adapter |

Reserved, universal sense only; prefix the ecosystem name for the native sense ("Go package", "Maven module", "NuGet package", "Cabal component", "MSBuild target"):
package, module, library, app, component, artifact, target, workspace, service, crate.

Usage:

- Architecture documents, ADRs and diagrams use only section 2 terms.
- When a language-specific term is unavoidable, prefix it with the ecosystem name.
- Agents conflate "package" and "module" the same ways people do; the `repo:add-package` skill and the validator are the correction, not more prose.
