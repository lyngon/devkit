#!/usr/bin/env bash
# Run a check on what a commit holds: a checkout of the index, without the
# untracked files and the unstaged changes of the working tree. The check gets
# the root of the checkout as its last argument.
#
# A commit hook runs in the working tree, where prek sets unstaged changes to
# tracked files aside but leaves untracked files in place (issue 94). A check
# that reads the tree as a whole would let a file that the commit leaves out
# fail the commit, and pass a staged file that names an untracked one or links
# to it. In the checkout, every path the check probes is one the commit holds.
#
# Usage: on-the-index.sh <check> [<argument>...]
set -euo pipefail

(($# > 0)) || {
  echo "usage: on-the-index.sh <check> [<argument>...]" >&2
  exit 2
}

# From a subdirectory, checkout-index --all would write only the files below it.
cd "$(git rev-parse --show-toplevel)"
checkout=$(mktemp -d)
trap 'rm -rf "$checkout"' EXIT
# A commit of named paths hands the hooks a temporary index in GIT_INDEX_FILE,
# which checkout-index reads.
git checkout-index --all --prefix="$checkout/"
"$@" "$checkout"
