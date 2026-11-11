---
type: regex
pattern: '\bvenv(\.enable\s*=\s*true|\s*=\s*\{[^}]*\benable\s*=\s*true)'
target: { source: file, path: devenv.nix }
---
