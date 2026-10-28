#!/usr/bin/env bash
# Seed the run's empty working directory as the case
# pull-request-says-it-met-nothing does, with tmp/ ignored, and put the
# branch's work trace and its Attention section under tmp/work-trace/, where
# build:work-trace leaves them, untracked.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

bash "$case_dir/../pull-request-says-it-met-nothing/seed-workspace.sh" "$case_dir/planted"
mkdir -p tmp/work-trace
cp -R "$case_dir/work-trace/." tmp/work-trace/
