---
type: regex
pattern: '"tides-noaa:test"\s*=\s*\{[^}]*\bafter\s*=\s*\[\s*"devenv:enterShell"\s*\]'
target: { source: file, path: libs/tides-noaa/devenv.nix }
---
