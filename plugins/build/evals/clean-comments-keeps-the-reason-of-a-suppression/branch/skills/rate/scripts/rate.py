# ruff: noqa: INP001  # a script that the skill runs by its path, which no package holds
"""Print the rate of each pair given, as in `python3 "${CLAUDE_SKILL_DIR}/scripts/rate.py" EUR/SEK`."""

import json
import pathlib
import sys
import urllib.request

HOOKS = pathlib.Path(__file__).resolve().parents[3] / "hooks"
# Put the plugin's hooks on the path.
if str(HOOKS) not in sys.path:
    sys.path.append(str(HOOKS))

import pairs  # noqa: E402  # importable only once the lines above have put the hooks on the path

PROVIDER_URL = "https://rates.example.com/v1/latest"


def main() -> int:
    for argument in sys.argv[1:]:
        # Read the pair the way the hooks do.
        base, quote = pairs.parse(argument)
        with urllib.request.urlopen(f"{PROVIDER_URL}?base={base}&symbols={quote}", timeout=5) as response:
            print(argument, json.load(response)["rates"][quote])
    return 0


if __name__ == "__main__":
    sys.exit(main())
