---
type: regex
pattern: "^/nix/store/[^/]+/bin/python3\n"
target: { source: file, path: path-of-this-run.txt }
---
