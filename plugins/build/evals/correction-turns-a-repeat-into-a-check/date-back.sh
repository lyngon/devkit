#!/usr/bin/env bash
set -euo pipefail

ledger_file=docs/mistakes/$1
fixed_date=$2
recent=$(date -d "$3" +%F)
sed -i "s/^- \*\*Date\*\*: $fixed_date\$/- **Date**: $recent/" "$ledger_file"
if ! grep -q "^- \*\*Date\*\*: $recent\$" "$ledger_file"; then
  echo "date-back.sh: $ledger_file holds no line '- **Date**: $fixed_date' to date back" >&2
  exit 1
fi
