#!/usr/bin/env python3
"""Check that a session here loads the checkout's plugins without moving the marketplace.

Claude Code keeps one registration of a marketplace per user, and every session
that starts where a settings file declares the marketplace from another source
registers it again from that source. Every repository that `/repo:init` sets up
declares `lyngon` from GitHub, so when this repository declared it from its
working tree, a session here that followed a session anywhere else loaded the
copies of the last install, and a session elsewhere that followed one here
loaded this working tree (issue 83).

Two things fail:

- `.claude/settings.json` declares a marketplace other than the settings
  template in the reference `repo-files.md` of the init skill does.
- The shell does not hand Claude Code this checkout's `plugins/` in
  `CLAUDE_CODE_PLUGIN_DIRS`, which loads every plugin of the checkout for the
  session and leaves the registration alone.

Usage: checkout-plugins.py <the value of CLAUDE_CODE_PLUGIN_DIRS in the shell>

Run through `devenv test`. Exits 1 when a check fails.
"""

import itertools
import json
import pathlib
import sys
import typing as t

import markdown_it

ROOT: pathlib.Path = pathlib.Path(__file__).resolve().parents[2]
REFERENCE: str = "plugins/repo/skills/init/references/repo-files.md"
SETTINGS: str = ".claude/settings.json"


def marketplaces(settings_text: str) -> object:
    """Return the marketplaces that the text of a settings file declares, or None when it declares none."""
    settings = t.cast("object", json.loads(settings_text))
    if not isinstance(settings, dict):
        return None
    # The keys of a JSON object are strings.
    return t.cast("dict[str, object]", settings).get("extraKnownMarketplaces")


def template(markdown: str) -> str:
    """Return the text of the settings template, the first JSON block under its heading.

    Raises LookupError when the reference has no such block.
    """
    tokens = markdown_it.MarkdownIt().parse(markdown)
    under_heading = False
    for opening, inline in itertools.pairwise(tokens):
        if opening.type == "heading_open":
            under_heading = opening.tag == "h2" and inline.content == SETTINGS
        if under_heading and opening.type == "fence" and opening.info.strip() == "json":
            return opening.content
    message = f"{REFERENCE} has no JSON block under the heading {SETTINGS}"
    raise LookupError(message)


def declaration_difference() -> str | None:
    """Return how this repository's marketplace declaration differs from the template's, or None."""
    wanted = marketplaces(template((ROOT / REFERENCE).read_text(encoding="utf-8")))
    present = marketplaces((ROOT / SETTINGS).read_text(encoding="utf-8"))
    if wanted == present:
        return None
    return (
        f"{SETTINGS} declares the marketplaces {json.dumps(present)}, and the settings template "
        f"in {REFERENCE} declares {json.dumps(wanted)}; a second source for one marketplace moves "
        "the registration that every session on the machine shares"
    )


def plugin_dirs_difference(plugin_dirs: str) -> str | None:
    """Return how the shell's CLAUDE_CODE_PLUGIN_DIRS differs from this checkout's plugins directory, or None."""
    wanted = ROOT / "plugins"
    if plugin_dirs and pathlib.Path(plugin_dirs).resolve() == wanted:
        return None
    return (
        f"the shell sets CLAUDE_CODE_PLUGIN_DIRS to {plugin_dirs!r}, not to {wanted}, "
        "so a session started from it loads the plugins of the last install instead of this checkout"
    )


def main() -> int:
    """Print the result of both checks and return the exit status: 0 when neither fails, 1 otherwise."""
    if len(sys.argv) != 2:  # noqa: PLR2004  # the program and its one argument
        print(__doc__, file=sys.stderr)
        return 1
    results = {
        f"{SETTINGS} declares the marketplace as the settings template does": declaration_difference(),
        "the shell loads this checkout's plugins": plugin_dirs_difference(sys.argv[1]),
    }
    failures = 0
    for check, found in results.items():
        if found is None:
            print(f"ok: {check}")
        else:
            print(f"FAIL: {found}")
            failures += 1
    if failures:
        print(f"test-checkout-plugins: {failures} failure(s)", file=sys.stderr)
        return 1
    print("test-checkout-plugins: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
