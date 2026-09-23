#!/usr/bin/env bash
# Bisection script to find which test file creates an unwanted file or
# directory. Runs the test files matching the glob one by one with the given
# test command and stops at the first one after which the path exists.
#
# Usage:   find-polluter.sh <path-to-check> <test-glob> <test-command>
# Example: find-polluter.sh '.git' 'src/**/*.test.ts' 'npm test'
#
# The test command is a shell string; the test file is appended to it as a
# single quoted argument.

set -euo pipefail

if [ $# -ne 3 ]; then
  echo "Usage: $0 <path-to-check> <test-glob> <test-command>" >&2
  echo "Example: $0 '.git' 'src/**/*.test.ts' 'npm test'" >&2
  exit 2
fi

POLLUTION_CHECK="$1"
TEST_PATTERN="$2"
TEST_COMMAND="$3"

echo "Searching for the test that creates: $POLLUTION_CHECK"
echo "Test glob: $TEST_PATTERN"
echo "Test command: $TEST_COMMAND <file>"
echo ""

# find emits ./-prefixed paths, so accept the glob written with or without a
# leading ./
TEST_PATTERN="${TEST_PATTERN#./}"
# find -path cannot match '**/' against zero directory levels, so a glob like
# src/**/*.test.ts would skip src/top.test.ts; also try the glob with '**/'
# collapsed to cover files directly under the base directory.
TEST_FILES=()
while IFS= read -r file; do
  TEST_FILES+=("$file")
done < <(find . \( -path "./$TEST_PATTERN" -o -path "./${TEST_PATTERN//\*\*\//}" \) -type f | sort -u)
TOTAL=${#TEST_FILES[@]}

echo "Found $TOTAL test files"
echo ""

if [ "$TOTAL" -eq 0 ]; then
  echo "No test files match the glob." >&2
  exit 2
fi

if [ -e "$POLLUTION_CHECK" ]; then
  echo "$POLLUTION_CHECK already exists; remove it before bisecting." >&2
  exit 2
fi

COUNT=0
for TEST_FILE in "${TEST_FILES[@]}"; do
  COUNT=$((COUNT + 1))
  echo "[$COUNT/$TOTAL] Testing: $TEST_FILE"

  # Run one test file; a failing test is not what we are looking for.
  bash -c "$TEST_COMMAND \"\$1\"" find-polluter "$TEST_FILE" > /dev/null 2>&1 || true

  if [ -e "$POLLUTION_CHECK" ]; then
    echo ""
    echo "FOUND POLLUTER"
    echo "   Test: $TEST_FILE"
    echo "   Created: $POLLUTION_CHECK"
    echo ""
    echo "Pollution details:"
    ls -la "$POLLUTION_CHECK"
    echo ""
    echo "To investigate:"
    echo "  $TEST_COMMAND '$TEST_FILE'    # Run just this test file"
    echo "  cat '$TEST_FILE'    # Review the test code"
    exit 1
  fi
done

echo ""
echo "No polluter found: every test file left $POLLUTION_CHECK absent."
exit 0
