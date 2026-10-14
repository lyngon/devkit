#!/usr/bin/env python3
"""Compare the workflow templates of repo:init with this repository's workflows.

The reference `repo-files.md` of the init skill holds the text of every
workflow that `/repo:init` writes, and `.github/workflows/` holds the same
workflows for this repository. A run of the workflows here counts as proof of
the templates, which holds only while the two read the same.

Three things fail: a template and a workflow whose texts differ, a template
whose workflow this repository lacks, and a workflow here that has no template.
The last one also keeps the test from passing because it found no template.

A template is a fenced block right after a paragraph that starts with the path
of the workflow as a code span.

Run through `devenv test`. Exits 1 when a comparison fails.
"""

import difflib
import pathlib
import sys

import markdown_it

ROOT: pathlib.Path = pathlib.Path(__file__).resolve().parents[2]
REFERENCE: str = "plugins/repo/skills/init/references/repo-files.md"
WORKFLOWS: str = ".github/workflows"


def templates(markdown: str) -> dict[str, str]:
    """Return the text of every workflow template in the document, by the path of its workflow."""
    tokens = markdown_it.MarkdownIt().parse(markdown)
    found: dict[str, str] = {}
    for lead_in, closing, block in zip(tokens, tokens[1:], tokens[2:], strict=False):
        opening = lead_in.children[0] if lead_in.children else None
        if (
            block.type == "fence"
            and closing.type == "paragraph_close"
            and opening is not None
            and opening.type == "code_inline"
            and opening.content.startswith(f"{WORKFLOWS}/")
        ):
            found[opening.content] = block.content
    return found


def workflows(root: pathlib.Path) -> dict[str, str]:
    """Return the text of every workflow of the repository, by its path from the root."""
    return {
        path.relative_to(root).as_posix(): path.read_text(encoding="utf-8")
        for path in sorted((root / WORKFLOWS).iterdir())
    }


def difference(path: str, template: str | None, workflow: str | None) -> str | None:
    """Return what sets the template of a workflow apart from the workflow, or None when they read the same."""
    if template is None:
        return (
            f"{path} has no template in {REFERENCE}: a template is a fenced block right after a paragraph "
            f"that starts with `{path}`"
        )
    if workflow is None:
        return f"{REFERENCE} has a template of {path}, and this repository has no such workflow to prove it"
    if template == workflow:
        return None
    lines = difflib.unified_diff(
        template.splitlines(keepends=True),
        workflow.splitlines(keepends=True),
        fromfile=f"the template of {path} in {REFERENCE}",
        tofile=path,
    )
    return f"the template of {path} and the workflow differ; change one so that they read the same\n{''.join(lines)}"


def main() -> int:
    """Print the result of every comparison and return the exit status: 0 when none fails, 1 otherwise."""
    wanted = templates((ROOT / REFERENCE).read_text(encoding="utf-8"))
    present = workflows(ROOT)
    failures = 0
    for path in sorted(wanted.keys() | present.keys()):
        found = difference(path, wanted.get(path), present.get(path))
        if found is None:
            print(f"ok: the template of {path} reads as the workflow")
        else:
            print(f"FAIL: {found.rstrip()}")
            failures += 1
    if failures:
        print(f"test-workflow-templates: {failures} failure(s)", file=sys.stderr)
        return 1
    print("test-workflow-templates: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
