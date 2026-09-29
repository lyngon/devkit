#!/usr/bin/env bash
# SessionStart hook of the conventions plugin: prints session-start.txt, and
# the standard output of a SessionStart hook is added to the session context.
# It says which devkit skills to invoke and when, and that no skill loads on
# its own, the conventions included. It has no matcher, so it runs for every
# SessionStart source.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

cat "$here/session-start.txt"
