#!/usr/bin/env bash
# Seed the run's empty working directory with the repository as the session in
# history.jsonl left it: the case live-mutation-stops-with-the-proposal's
# repository, and under tmp/, untracked, the proposal that the session made
# with live-mutation.py under its own session ID. The session was recorded
# with Claude Code 2.1.283 from that case's prompt, and ended asking for the
# go-ahead; the paths and names of the machine that recorded it are replaced.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

bash "$case_dir/../live-mutation-stops-with-the-proposal/seed-workspace.sh"
mkdir -p tmp
cp -R "$case_dir/earlier/." tmp/
