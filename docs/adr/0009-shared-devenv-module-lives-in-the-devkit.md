# The shared devenv module lives in this repository, which becomes the Lyngon devkit

`repo:init` copied forty lines of baseline git hooks and the MCP server file into every repository's `devenv.nix`, the same drift problem we refused for prose.
devenv can import a subdirectory of an input (`imports: [lyngon/devenv]`), pinned per consumer in `devenv.lock`, so the baseline can be one module.
It could live in its own repository, but the module and the `init` skill change together (`init` writes `lyngon.enable = true`, the module defines what that means), so they share a history here, and this repository's own shell imports the module and tests it on every `devenv test`.
The repository is renamed from `skills` to `devkit` to match: everything a Lyngon repository needs to be a Lyngon repository.

## Consequences

- Two fetch mechanisms pull this repository: the Claude Code plugin cache and devenv inputs. Both pin a commit; neither cares about the other's files.
- A remote import's `devenv.yaml` is not merged, so consumers declare the `git-hooks` input themselves and `init` keeps writing it.
- Every value the module sets is a `lib.mkDefault`, so a repository overrides a single hook in place with a comment, instead of forking the baseline.
- `secretspec` cannot be part of the module because it is configured in `devenv.yaml`; `init` keeps writing that section.
