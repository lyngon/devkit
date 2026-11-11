---
type: regex
pattern: '"tides-noaa:test"\s*=\s*\{[^}]*\bbefore\s*=\s*\[\s*"devenv:enterTest"\s*\]'
target: { source: file, path: libs/tides-noaa/devenv.nix }
---
