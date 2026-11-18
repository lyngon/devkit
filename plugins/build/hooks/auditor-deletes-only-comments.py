#!/usr/bin/env python3
"""PreToolUse hook on Edit, Write, NotebookEdit and Bash: build:comment-auditor deletes comments and changes no code.

Of the auditor's Edit or Write of a file inside a repository it lexes the file before and after the call with
pygmentize, leaves out the comments and the docstrings, and refuses the call when the code that remains differs.
It compares that code line by line, each line by its indentation, its tokens and whether space parts each token
from the one before, so a comment may go with the space around it, and a blank line with it. Pygments takes each
triple-quoted Python string that starts a line for a docstring, so the hook lets the auditor delete one that is not.
Of the auditor's shell commands it refuses each write into a repository that shell_writes can name before the
command runs. Any other program may write files as well, an interpreter or git among them, and the hook cannot
tell that from a read.
"""

import ast
import dataclasses
import difflib
import json
import pathlib
import re
import shutil
import subprocess
import sys
import typing as t

import shell_syntax
import shell_writes

AUDITOR = "build:comment-auditor"

AUDITS = f"{AUDITOR} deletes comments and changes no code"

COMMENTS = frozenset(
    {
        "Token.Comment",
        "Token.Comment.Multiline",
        "Token.Comment.Single",
        "Token.Comment.Special",
        "Token.Literal.String.Doc",
    }
)

SHEBANG = "Token.Comment.Hashbang"

UNKNOWN_LANGUAGE = "text"

SPACE = re.compile(r"(\s+)")


class UncheckedError(Exception):
    """The hook cannot tell the comments of a file from its code. Its message says why."""


@dataclasses.dataclass(frozen=True, slots=True)
class Token:
    """A token of code, and whether space or a comment parts it from the token before it on its line."""

    text: str
    spaced: bool


@dataclasses.dataclass(frozen=True, slots=True)
class Line:
    """A line of code without its comments: its indentation and its tokens."""

    indentation: str
    tokens: tuple[Token, ...]

    @t.override
    def __str__(self) -> str:
        return "".join((" " if token.spaced else "") + token.text for token in self.tokens)


def json_object(value: object, name: str) -> dict[str, object]:
    """Return the value as a JSON object, whose keys are strings. Exits 1, naming it, when it is no object."""
    if not isinstance(value, dict):
        sys.exit(f"auditor-deletes-only-comments.py: {name} is no JSON object")
    return t.cast("dict[str, object]", value)


def in_a_repository(path: pathlib.Path) -> bool:
    """Return whether the path lies inside a repository."""
    return any((directory / ".git").exists() for directory in path.parents)


def pygmentize(*arguments: str, given: str = "") -> str:
    """Return what pygmentize prints for the arguments, with the text given on its stdin.

    Raises UncheckedError when pygmentize is not on the PATH or fails.
    """
    if shutil.which("pygmentize") is None:
        message = "pygmentize, which tells comments from code, is not on the PATH that Claude Code gives its hooks"
        raise UncheckedError(message)
    try:
        return subprocess.run(
            ["pygmentize", *arguments], input=given, capture_output=True, check=True, text=True, encoding="utf-8"
        ).stdout
    except subprocess.CalledProcessError as error:
        message = f"pygmentize failed: {t.cast('str', error.stderr).strip()}"
        raise UncheckedError(message) from error


def tokens(language: str, text: str) -> list[tuple[str, str]]:
    """Return the tokens of a text in a language, each its type and its text, as Pygments lexes them."""
    raw = pygmentize("-l", language, "-f", "raw", given=text)
    lexed: list[tuple[str, str]] = []
    for line in raw.split("\n"):
        if line:
            kind, _, value = line.partition("\t")
            lexed.append((kind, t.cast("str", ast.literal_eval(value))))
    return lexed


def pieces(lexed: list[tuple[str, str]]) -> list[tuple[t.Literal["code", "space", "comment"], str]]:
    """Return the pieces of a text: its code, its space and its comments, text and a shebang split at their spaces."""
    split: list[tuple[t.Literal["code", "space", "comment"], str]] = []
    for kind, value in lexed:
        if kind in COMMENTS:
            split.append(("comment", value))
        elif kind in {"Token.Text", SHEBANG} or kind.startswith("Token.Text."):
            split.extend(("space" if run.isspace() else "code", run) for run in SPACE.split(value) if run)
        else:
            split.append(("code", value))
    return split


def code_lines(language: str, text: str) -> list[Line]:
    """Return the lines of a text that hold code, without its comments.

    A line ends at a line break in space or in a comment, never in a string. Space before the first token or
    comment of a line is its indentation.
    """
    lines: list[Line] = []
    code: list[Token] = []
    indentation, begun, spaced = "", False, False
    for kind, value in pieces(tokens(language, text)):
        if kind == "code":
            code.append(Token(value, spaced=spaced and bool(code)))
            begun, spaced = True, False
            continue
        for index, part in enumerate(value.split("\n")):
            if index > 0:
                if code:
                    lines.append(Line(indentation, tuple(code)))
                indentation, code, begun, spaced = "", [], False, False
            if part and kind == "space" and not begun:
                indentation += part
            elif part:
                begun, spaced = True, True
    if code:
        lines.append(Line(indentation, tuple(code)))
    return lines


def change(before: list[Line], after: list[Line]) -> str | None:
    """Return what the first difference between the code before and after does to it, or None when it is the same."""
    matcher = difflib.SequenceMatcher(a=before, b=after, autojunk=False)
    for tag, first_before, _, first_after, _ in matcher.get_opcodes():
        if tag == "delete":
            return f"it removes the code `{before[first_before]}`"
        if tag == "insert":
            return f"it adds the code `{after[first_after]}`"
        if tag == "replace" and str(before[first_before]) == str(after[first_after]):
            return f"it changes the indentation of the code `{before[first_before]}`"
        if tag == "replace":
            return f"it changes the code `{before[first_before]}` to `{after[first_after]}`"
    return None


def language_of(path: pathlib.Path) -> str:
    """Return the name of the Pygments lexer for the file. Raises UncheckedError when Pygments knows none."""
    language = pygmentize("-N", path.name).strip()
    if language == UNKNOWN_LANGUAGE:
        message = "Pygments knows no language by its file name"
        raise UncheckedError(message)
    return language


def text_of(path: pathlib.Path) -> str:
    """Return the text of a file, empty when there is none. Raises UncheckedError when it is not UTF-8."""
    if not path.is_file():
        return ""
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError as error:
        message = "it is not UTF-8 text"
        raise UncheckedError(message) from error


def edited(before: str, tool_input: dict[str, object]) -> str | None:
    """Return the text after an Edit, or None when its old_string is not in the text as many times as it needs."""
    old, new = tool_input.get("old_string"), tool_input.get("new_string")
    if not isinstance(old, str) or not isinstance(new, str) or not old:
        return None
    replace_all = tool_input.get("replace_all") is True
    count = before.count(old)
    if count == 0 or (count > 1 and not replace_all):
        return None
    return before.replace(old, new) if replace_all else before.replace(old, new, 1)


def refusal(reason: str) -> dict[str, object]:
    """Return the hook's output that refuses the call for the reason."""
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }


def unchecked(target: str, why: str) -> dict[str, object]:
    """Return the refusal of an edit of a file whose comments the hook cannot tell from its code."""
    reason = (
        f"{AUDITS}, and this hook cannot check an edit of {target}, since {why}."
        " Leave its comments as they are, and report them skipped."
    )
    return refusal(reason)


def shell_answer(command: str, cwd: pathlib.Path) -> dict[str, object] | None:
    """Return the hook's output for a shell command of the auditor, or None to let it run."""
    through = (
        "It deletes comments with Edit, whose edits this hook checks, and writes through the shell into no repository"
    )
    try:
        part = shell_writes.first_write(command, cwd, in_a_repository)
    except shell_syntax.UnreadableError as error:
        reason = (
            f"{AUDITS}. {through}, and this hook cannot read this command, since {error}, so it cannot tell what it"
            " writes. Write the command without that construct."
        )
        return refusal(reason)
    if part is None:
        return None
    reason = (
        f"{AUDITS}. {through}, so it may not write through `{part}`."
        " This hook counts a file that a path with a variable or a substitution names as one inside a repository."
    )
    return refusal(reason)


def file_answer(
    tool_name: str, tool_input: dict[str, object], target: str, path: pathlib.Path
) -> dict[str, object] | None:
    """Return the hook's output for the auditor's edit of a file inside a repository, or None to let it run."""
    if tool_name == "NotebookEdit":
        return unchecked(target, "it is a notebook")
    try:
        before = text_of(path)
        after = tool_input.get("content") if tool_name == "Write" else edited(before, tool_input)
        if not isinstance(after, str):
            reason = (
                f"{AUDITS}, and this hook cannot apply this Edit to {target} to check it, since its old_string is not"
                " in the file as many times as the Edit needs. Read the file, and give old_string as it stands there."
            )
            return refusal(reason)
        language = language_of(path)
        difference = change(code_lines(language, before), code_lines(language, after))
    except UncheckedError as error:
        return unchecked(target, str(error))
    if difference is None:
        return None
    reason = (
        f"{AUDITS}, and this {tool_name} changes the code of {target}: {difference}."
        " Make the edit again with only comments deleted, and leave the code as it is, also code that never runs."
        " Where a deleted comment covered for that code, mark the code MUST KILL in your report."
    )
    return refusal(reason)


def answer(hook_input: dict[str, object]) -> dict[str, object] | None:
    """Return the hook's output for a call, or None to let it run as it is.

    Exits 1 when the call names no file or no command.
    """
    if hook_input.get("agent_type") != AUDITOR:
        return None
    tool_name = str(hook_input.get("tool_name"))
    tool_input = json_object(hook_input.get("tool_input"), "its tool_input")
    cwd = pathlib.Path(str(hook_input.get("cwd", "")))
    if tool_name == "Bash":
        command = tool_input.get("command")
        if not isinstance(command, str):
            sys.exit("auditor-deletes-only-comments.py: its tool_input names no command")
        return shell_answer(command, cwd)
    target = tool_input.get("file_path", tool_input.get("notebook_path"))
    if not isinstance(target, str):
        sys.exit("auditor-deletes-only-comments.py: its tool_input names no file")
    path = (cwd / target).resolve()
    return file_answer(tool_name, tool_input, target, path) if in_a_repository(path) else None


def main() -> None:
    """Read the hook input on stdin and print the output, if any."""
    output = answer(json_object(t.cast("object", json.load(sys.stdin)), "the hook input"))
    if output is not None:
        json.dump(output, sys.stdout)


if __name__ == "__main__":
    main()
