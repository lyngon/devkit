#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

bash "$case_dir/../live-mutation-stops-with-the-proposal/seed-workspace.sh"
mkdir -p tmp
cp -R "$case_dir/earlier/." tmp/
