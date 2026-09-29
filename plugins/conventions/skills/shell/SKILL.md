---
name: shell
description: Lyngon shell conventions. Invoke before writing or editing a shell script or a file under a scripts/ directory.
user-invocable: false
paths:
  - "**/*.sh"
  - "**/*.bash"
  - "**/scripts/**"
---

# Shell conventions

- A shell script is bash: `#!/usr/bin/env bash`, then `set -euo pipefail` before its first command.
- Under `pipefail` a pipeline fails when any command in it fails, so `cmd | grep -q pattern` is false whenever `cmd` exits non-zero, even on a match. Never pipe a command whose failure is expected into `grep -q`; capture its output first and match the variable:

  ```bash
  out=$(cmd 2>&1) || true
  grep -q 'expected message' <<<"$out"
  ```

- A command meant for a person to run by hand (in a README, a runbook or a plan step) is POSIX sh, or runs through `bash -c '...'`. The person's shell may be zsh, where bash-only syntax such as `${PIPESTATUS[0]}` prints nothing.

## With devenv

- A script that a hook or task runs is a `pkgs.writeShellApplication` with its dependencies in `runtimeInputs`, never a bare path that assumes PATH. It sets the same options and runs ShellCheck when it is built.

## With the Lyngon baseline

- Every script is shellcheck clean; the `shellcheck` hook checks it.
- Silence a single finding with `# shellcheck disable=SC2086  # reason` on the line above it.
