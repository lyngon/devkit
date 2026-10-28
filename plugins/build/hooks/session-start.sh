#!/usr/bin/env bash
# SessionStart hook of the build plugin: prints the standing instructions, and
# the standard output of a SessionStart hook is added to the session context.
# It has no matcher, so it runs again after a compaction, and fills in the
# plugin's root where the text names the file of /build:auto.
set -euo pipefail

here=$(cd "${BASH_SOURCE[0]%/*}" && pwd)
root=${here%/*}

text=$(<"$here/standing-instructions.txt")
# A quoted replacement is taken as it is, an & in the path included.
printf '%s\n' "${text//<path>/"$root"}"
