# Convention documents live in `shared/` and are symlinked; behaviour is shared through plugin dependencies

Two plugins needed the same ADR and CONCEPTS format text, and `repo:init` re-implemented the interview method that `discover` already provides.
Byte-identical copies (a consequence in ADR 0007) kept the files from drifting but not from being copied.
Claude Code dereferences a symlink that points elsewhere in the same marketplace when it copies a plugin into its cache, and it auto-installs plugins listed under `dependencies`.

We therefore keep every convention document once, under `shared/`, symlinked from the plugins that need it, and share behaviour by dependency: `repo` depends on `discover` and invokes `discover:interview` and `discover:domain-model` instead of carrying copies.
A convention is not a concern, so no plugin owns the format files; `repo` installs the convention into repositories and `discover` exercises it.
A repository may override a convention document from `docs/conventions/`, which the skills read first.

## Consequences

- `repo` cannot be installed without `discover`; Claude Code enables both together and refuses to disable `discover` while `repo` is enabled.
- Symlinks are committed, which rules out Windows checkouts. All Lyngon machines run Nix.
- The validator checks that every symlink under `plugins/` resolves into `shared/` and that every file in `shared/` is linked from at least one plugin.
- Dependency version ranges resolve against git tags named `<plugin>--v<version>`; until releases are tagged, dependencies are declared bare.
- The byte-identical consequence in ADR 0007 no longer applies.
