# The prerequisite is the Lyngon baseline; using devenv is a condition, not a prerequisite

ADR 0014 named the second prerequisite `devenv`, defined as importing `lyngon/devenv`, and let a skill whose `paths` were Nix files speak about it unconditionally.
That conflated two things: a repository can use devenv without the baseline, and `*.nix` files exist in flake and NixOS repositories that never touch devenv, so a documents-only plugin told every such repository to set `lyngon.enable = true`.
The prerequisite is renamed `baseline`, matching the glossary; generic devenv facts (tools from `devenv.nix`, `devenv test`, `secretspec`) are a condition any plugin may write for under a `With devenv` heading; `lyngon.*`, the `lyngon` input and the named hooks are baseline terms; and no `paths` value makes a skill conditional.

## Consequences

- Declarations are `documents`, `baseline`, `structure`. Bundles and `init`'s scope question use the same names.
- A plugin declaring `baseline` may name devenv terms anywhere; a `With the Lyngon baseline` section allows devenv terms too.
- The Nix convention skill has four parts: universal Nix, with devenv, with the baseline, with the structure.
