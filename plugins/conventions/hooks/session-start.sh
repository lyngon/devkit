#!/usr/bin/env bash
# SessionStart hook of the conventions plugin: prints session-start.txt, and
# the standard output of a SessionStart hook is added to the session context.
# It says when to invoke the conventions skills, and that none loads on its
# own. The standing instructions come from the build plugin's own hook. It has
# no matcher, so it runs for every SessionStart source.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

cat "$here/session-start.txt"
