# One workspace and one lockfile per language at the repository root, and one version of every internal library

Each language's workspace lives at the repository root with explicitly listed members and a single lockfile, and internal libraries carry no version: consumers use HEAD and a breaking change updates every consumer in the same commit.
Per-package lockfiles would let two libraries pin different versions of one dependency, but that is the drift we want to fail loudly, and a single workspace is what language servers, agents and CI caches handle best.
Only a library with an external consumer gets semver and a changelog, because only an external consumer cannot be updated atomically; an app is identified by its deployable's digest.

## Consequences

- Languages are enabled once at the root; a package's `devenv.nix` holds only its tasks, hooks and processes. `/repo:init` no longer writes `languages.*` into package files.
- A library manifest declares constraints, the lockfile pins for this repository's deployables, and infra never resolves dependencies.
- CI must be dependency-aware: a change to a library runs the tests of every package that depends on it.
- A breaking change to an internal library is one larger pull request instead of a migration period; at Lyngon's size, with agents doing the mechanical consumer updates, that is the cheaper trade.
- Workspace member lists are explicit and checked by the validator; a glob would match other languages' directories.
