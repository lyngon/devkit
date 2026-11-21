# ruff: noqa: INP001  # a module beside the hook scripts that import it, which no package holds
"""Read a currency pair such as `EUR/SEK`, as every hook and script of this plugin reads one."""

import re

PAIR = re.compile(r"([A-Z]{3})/([A-Z]{3})")


class PairError(ValueError):
    """A text names no currency pair."""


def parse(text: str) -> tuple[str, str]:
    """Return the base and the quote currency that `text` names, or raise PairError."""
    match = PAIR.fullmatch(text)
    if match is None:
        raise PairError(text)
    return match[1], match[2]
