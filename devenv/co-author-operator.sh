#!/usr/bin/env bash
# prepare-commit-msg hook of the baseline. In an agent session agent-identity
# exports LYNGON_AGENT_OPERATOR as "Name <email>", and the commit names the
# operator as co-author; anywhere else the message stays as it is. The only
# argument is the file of the message.
set -euo pipefail

[[ -n ${LYNGON_AGENT_OPERATOR-} ]] || exit 0
git interpret-trailers --in-place --if-exists addIfDifferent \
  --trailer "Co-authored-by: $LYNGON_AGENT_OPERATOR" "$1"
