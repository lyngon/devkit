#!/usr/bin/env bash
set -euo pipefail

case_directory=$(dirname "${BASH_SOURCE[0]}")
cp -R "$case_directory/../architect-stops-at-the-design-gate/workspace/." .
printf '__pycache__/\n' >.gitignore
git init -q -b main
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "chore: seed the repository"
git switch -q -c feat/supported-currencies
cp -R "$case_directory/workspace/." .
git add -A
git -c user.name=seed -c user.email=seed@example.com commit -q -m "feat(rates): refuse a currency that the provider does not quote"
sed -i '/^#/d' rates/client.py
