#!/usr/bin/env bash
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
