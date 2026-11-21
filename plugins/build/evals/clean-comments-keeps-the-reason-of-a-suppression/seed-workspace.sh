#!/usr/bin/env bash
# Seed the run's empty working directory as the git repository of a Claude Code
# plugin: main with its hooks, and the branch feat/rate-skill with one commit
# that adds the script of a skill, which imports a module of the hooks.
set -euo pipefail

case_directory=$(dirname "${BASH_SOURCE[0]}")
cp -R "$case_directory/main/." .
git init -q -b main
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "feat: refuse a currency pair written in lower case"
git switch -q -c feat/rate-skill
cp -R "$case_directory/branch/." .
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "feat(rate): print the rate of a currency pair"
