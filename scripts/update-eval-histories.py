#!/usr/bin/env python3
"""Make the hook output that each eval history records what the hooks print at head.

A case that resumes a recorded session names the transcript in `context.history_file` of its case.yaml. A hook
record of the transcript, an attachment of type hook_success, hook_non_blocking_error or hook_blocking_error, holds
what one hook command printed for one hook event. The program replays each such event: it runs every hook that a
plugin of the checkout registers for the event with that command, in hooks/hooks.json or in the frontmatter of a
skill or an agent, on the input that the transcript records, in an empty working directory and with the variables
that Claude Code gives a hook. In what the hooks print it writes the checkout as /recorded/devkit and the working
directory as the one the transcript records, as the recording did.

The records of a command in an event are current when they hold the outputs of those hooks one for one, leaving out
a hook that prints nothing, since such a hook leaves no record. A record that is not current takes the output that no
record holds. A record left over is deleted when nothing in the transcript hangs off it. Any other difference needs a
new recording, and the program names the line.

Usage: update-eval-histories.py [--check] [<root>]

Updates the histories of the checkout at <root>, by default the working tree around the working directory. With
--check it changes nothing and exits 1 when a history is behind. Without it, it exits 1 when a history needs a new
recording.
"""

import argparse
import collections.abc as ct
import dataclasses
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import typing as t

RECORDED_CHECKOUT = "/recorded/devkit"

HOOK_RECORDS = frozenset({"hook_success", "hook_non_blocking_error", "hook_blocking_error"})

NON_BLOCKING_ERROR = "Failed with non-blocking status code: "

STOP_FEEDBACK = "Stop hook feedback:"

DEFAULT_TIMEOUT_SECONDS = 60.0


class HistoryError(Exception):
    """A history or a hook registration that the program cannot read."""


@dataclasses.dataclass(frozen=True, slots=True)
class Hook:
    """A hook command that a plugin registers for an event, for the values its matcher matches, or all without one."""

    plugin: pathlib.Path
    event: str
    matcher: str
    command: str
    timeout: float

    def matches(self, value: str) -> bool:
        """Say whether the hook runs for an event with this value, a tool name or a SessionStart source."""
        return self.matcher in {"", "*"} or re.fullmatch(self.matcher, value) is not None


@dataclasses.dataclass(frozen=True, slots=True)
class Output:
    """What a hook did on one input: its exit status and what it printed on each stream."""

    code: int
    stdout: str
    stderr: str

    @property
    def silent(self) -> bool:
        """Say whether the hook printed nothing and succeeded, which Claude Code records nowhere."""
        return self.code == 0 and not self.stdout and not self.stderr


@dataclasses.dataclass(frozen=True, slots=True)
class Event:
    """One hook event that a history records: the input each hook got, and the value its matchers are tried on."""

    name: str
    hook_input: dict[str, object]
    matched: str
    cwd: str


@dataclasses.dataclass(frozen=True, slots=True)
class Finding:
    """A line of a history that is behind: how, and what the update does to it, or None for a new recording."""

    line: int
    message: str
    action: t.Literal["rewritten", "deleted"] | None


def table(value: object, where: str) -> dict[str, object]:
    """Return a JSON object, or raise HistoryError naming where it was expected."""
    if not isinstance(value, dict):
        raise HistoryError(f"{where} is no JSON object")
    return t.cast("dict[str, object]", value)


def entries(value: object, where: str) -> list[object]:
    """Return a JSON array, or raise HistoryError naming where it was expected."""
    if not isinstance(value, list):
        raise HistoryError(f"{where} is no JSON array")
    return t.cast("list[object]", value)


def text(value: object, where: str) -> str:
    """Return a JSON string, or raise HistoryError naming where it was expected."""
    if not isinstance(value, str):
        raise HistoryError(f"{where} is no string")
    return value


def yaml_as_json(path: pathlib.Path, expression: str, *, front_matter: bool = False) -> object:
    """Return what a yq expression selects from a YAML file or from the frontmatter of a Markdown file."""
    options = ["--front-matter=extract"] if front_matter else []
    result = subprocess.run(
        ["yq", *options, "--output-format=json", "--indent=0", expression, str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise HistoryError(f"{path}: yq cannot read it: {result.stderr.strip()}")
    return t.cast("object", json.loads(result.stdout))


def registrations(hooks: object, plugin: pathlib.Path, where: str) -> ct.Iterator[Hook]:
    """Yield the command hooks of a hooks table, keyed by event, as hooks.json and frontmatter both write it."""
    for event, groups in table(hooks, where).items():
        for group in entries(groups, f"{where}: {event}"):
            group_table = table(group, f"{where}: a group of {event}")
            matcher = text(group_table.get("matcher", ""), f"{where}: a matcher of {event}")
            for hook in entries(group_table.get("hooks"), f"{where}: the hooks of a group of {event}"):
                hook_table = table(hook, f"{where}: a hook of {event}")
                if hook_table.get("type") != "command":
                    continue
                timeout = hook_table.get("timeout", DEFAULT_TIMEOUT_SECONDS)
                if not isinstance(timeout, int | float):
                    raise HistoryError(f"{where}: a timeout of {event} is no number")
                command = text(hook_table.get("command"), f"{where}: a command of {event}")
                yield Hook(plugin, event, matcher, command, float(timeout))


def registered_hooks(root: pathlib.Path) -> list[Hook]:
    """Return every command hook that a plugin of the checkout registers, in the order of the plugins' names."""
    hooks: list[Hook] = []
    for manifest in sorted(root.glob("plugins/*/.claude-plugin/plugin.json")):
        plugin = manifest.parent.parent
        hooks_file = plugin / "hooks" / "hooks.json"
        if hooks_file.is_file():
            hooks_table = table(t.cast("object", json.loads(hooks_file.read_text(encoding="utf-8"))), str(hooks_file))
            hooks.extend(registrations(hooks_table.get("hooks", {}), plugin, str(hooks_file)))
        for component in sorted([*plugin.glob("skills/*/SKILL.md"), *plugin.glob("agents/*.md")]):
            frontmatter_hooks = yaml_as_json(component, ".hooks // {}", front_matter=True)
            hooks.extend(registrations(frontmatter_hooks, plugin, str(component)))
    return hooks


def histories(root: pathlib.Path) -> list[pathlib.Path]:
    """Return the history file that each eval case of the checkout names in its case.yaml."""
    found: list[pathlib.Path] = []
    for case in sorted(root.glob("plugins/*/evals/*/case.yaml")):
        name = text(yaml_as_json(case, '.context.history_file // ""'), f"{case}: context.history_file")
        if name:
            found.append(case.parent / name)
    return found


def attachment_of(record: dict[str, object]) -> dict[str, object] | None:
    """Return the attachment of a hook record, or None for any other record."""
    attachment = record.get("attachment")
    if record.get("type") != "attachment" or not isinstance(attachment, dict):
        return None
    attachment = t.cast("dict[str, object]", attachment)
    kind = attachment.get("type")
    return attachment if isinstance(kind, str) and kind.startswith("hook_") else None


def command_of(attachment: dict[str, object], where: str) -> str:
    """Return the hook command that a hook record names, which a blocking error keeps inside its error."""
    if attachment.get("type") == "hook_blocking_error":
        return text(table(attachment.get("blockingError"), where).get("command"), f"{where}: its command")
    return text(attachment.get("command"), f"{where}: its command")


def content_of(record: dict[str, object]) -> str | list[dict[str, object]]:
    """Return the content of a message record: a string, or its blocks that are JSON objects."""
    message = record.get("message")
    content = t.cast("dict[str, object]", message).get("content") if isinstance(message, dict) else None
    if isinstance(content, str):
        return content
    blocks = t.cast("list[object]", content) if isinstance(content, list) else []
    return [t.cast("dict[str, object]", block) for block in blocks if isinstance(block, dict)]


def message_texts(record: dict[str, object]) -> list[str]:
    """Return the text of a message record: its string content, or the text of each of its text blocks."""
    content = content_of(record)
    if isinstance(content, str):
        return [content]
    return [block_text for block in content if isinstance(block_text := block.get("text"), str)]


def tool_use(records: list[dict[str, object]], tool_use_id: str) -> dict[str, object] | None:
    """Return the tool_use block with this ID from the assistant records."""
    for record in records:
        if record.get("type") != "assistant" or isinstance(content := content_of(record), str):
            continue
        for block in content:
            if block.get("type") == "tool_use" and block.get("id") == tool_use_id:
                return block
    return None


def ancestors(records: list[dict[str, object]], record: dict[str, object]) -> ct.Iterator[dict[str, object]]:
    """Yield the records above one in its conversation, nearest first, following parentUuid."""
    by_uuid = {record_uuid: other for other in records if isinstance(record_uuid := other.get("uuid"), str)}
    parent = record.get("parentUuid")
    while isinstance(parent, str) and parent in by_uuid:
        yield by_uuid[parent]
        parent = by_uuid[parent].get("parentUuid")


def continues_after_a_stop_hook(records: list[dict[str, object]], reply: dict[str, object]) -> bool:
    """Say whether the agent wrote a reply because a Stop hook blocked its previous one, after the last prompt."""
    for other in ancestors(records, reply):
        if other.get("type") != "user" or "toolUseResult" in other:
            continue
        if any(message_text.startswith(STOP_FEEDBACK) for message_text in message_texts(other)):
            return True
        if other.get("isMeta") is not True:
            return False
    return False


def stop_input(records: list[dict[str, object]], record: dict[str, object], where: str) -> dict[str, object]:
    """Return what a Stop hook gets: the reply it judges, and whether a Stop hook made the agent write that reply."""
    reply = next(
        (other for other in ancestors(records, record) if other.get("type") == "assistant" and message_texts(other)),
        None,
    )
    if reply is None:
        raise HistoryError(f"{where}: no reply of the agent stands above this Stop record")
    return {
        "stop_hook_active": continues_after_a_stop_hook(records, reply),
        "last_assistant_message": message_texts(reply)[-1],
    }


def event_of(records: list[dict[str, object]], record: dict[str, object], where: str) -> Event:
    """Return the hook event of a hook record, with the input that the transcript says its hooks got."""
    attachment = table(record.get("attachment"), where)
    name = text(attachment.get("hookEvent"), f"{where}: hookEvent")
    cwd = text(record.get("cwd"), f"{where}: cwd")
    hook_input: dict[str, object] = {
        "session_id": text(record.get("sessionId"), f"{where}: sessionId"),
        "cwd": cwd,
        "hook_event_name": name,
    }
    match name:
        case "SessionStart":
            source = text(attachment.get("hookName"), f"{where}: hookName").partition(":")[2]
            return Event(name, hook_input | {"source": source}, source, cwd)
        case "PreToolUse":
            tool_use_id = text(attachment.get("toolUseID"), f"{where}: toolUseID")
            block = tool_use(records, tool_use_id)
            if block is None:
                raise HistoryError(f"{where}: no tool call of the history has the ID {tool_use_id}")
            tool_name = text(block.get("name"), f"{where}: the name of tool call {tool_use_id}")
            calls = {"tool_name": tool_name, "tool_input": block.get("input"), "tool_use_id": tool_use_id}
            return Event(name, hook_input | calls, tool_name, cwd)
        case "Stop":
            return Event(name, hook_input | stop_input(records, record, where), "", cwd)
        case _:
            raise HistoryError(f"{where}: the program cannot replay a hook of the event {name}")


@dataclasses.dataclass(frozen=True, slots=True)
class Replayer:
    """Runs hooks as Claude Code does, in a scratch directory, and writes paths in their output as recorded."""

    root: pathlib.Path
    scratch: pathlib.Path

    def run(self, hook: Hook, event: Event) -> Output:
        """Run a hook on an event's input and return what it printed, with the paths that the recording replaced."""
        workdir = self.scratch / "cwd"
        workdir.mkdir(exist_ok=True)
        environment = {
            "PATH": os.environ.get("PATH", ""),
            "HOME": str(self.scratch / "home"),
            "GIT_CEILING_DIRECTORIES": str(self.scratch),
            "CLAUDE_PROJECT_DIR": str(workdir),
            "CLAUDE_PLUGIN_ROOT": str(hook.plugin),
            "CLAUDE_PLUGIN_DATA": str(self.scratch / "data" / hook.plugin.name),
        }
        if event.name == "SessionStart":
            environment["CLAUDE_ENV_FILE"] = str(self.scratch / "env-file.sh")
        result = subprocess.run(
            ["bash", "-c", hook.command],
            input=json.dumps(event.hook_input, separators=(",", ":")),
            capture_output=True,
            text=True,
            cwd=workdir,
            env=environment,
            timeout=hook.timeout,
            check=False,
        )

        def as_recorded(printed: str) -> str:
            return printed.replace(str(self.root), RECORDED_CHECKOUT).replace(str(workdir), event.cwd)

        return Output(result.returncode, as_recorded(result.stdout), as_recorded(result.stderr))


def rendered(hook_name: str, content: str) -> list[dict[str, str]]:
    """Return the reminder that Claude Code renders from the output of a hook that succeeded."""
    return [{"content": f"<system-reminder>\n{hook_name} hook success: {content}\n</system-reminder>"}]


def json_reply(stdout: str) -> dict[str, object] | None:
    """Return the JSON object that a hook printed in place of text, or None when it printed text."""
    if not stdout.lstrip().startswith("{"):
        return None
    try:
        return table(t.cast("object", json.loads(stdout)), "the output of a hook")
    except (ValueError, HistoryError):
        return None


def holds(record: dict[str, object], output: Output) -> bool:
    """Say whether a hook record is what Claude Code records of this output."""
    attachment = table(record.get("attachment"), "a hook record")
    reply = json_reply(output.stdout)
    match attachment.get("type"):
        case "hook_success":
            content = output.stdout.strip()
            expected = rendered(str(attachment.get("hookName")), content) if content else None
            return (
                output.code == 0
                and reply is None
                and attachment.get("stdout") == output.stdout
                and attachment.get("stderr") == output.stderr
                and attachment.get("content") == content
                and record.get("rendered") == expected
            )
        case "hook_non_blocking_error":
            return (
                output.code not in {0, 2}
                and attachment.get("exitCode") == output.code
                and attachment.get("stderr") == NON_BLOCKING_ERROR + output.stderr.strip()
            )
        case "hook_blocking_error":
            error = attachment.get("blockingError")
            return (
                output.code == 0
                and reply is not None
                and reply.get("decision") == "block"
                and isinstance(error, dict)
                and t.cast("dict[str, object]", error).get("blockingError") == reply.get("reason")
            )
        case _:
            return False


def rewrite(record: dict[str, object], output: Output) -> bool:
    """Write an output into a hook record that succeeded, and say whether the record can hold it."""
    attachment = table(record.get("attachment"), "a hook record")
    if attachment.get("type") != "hook_success" or output.code != 0 or json_reply(output.stdout) is not None:
        return False
    content = output.stdout.strip()
    attachment["content"] = content
    attachment["stdout"] = output.stdout
    attachment["stderr"] = output.stderr
    if content:
        record["rendered"] = rendered(str(attachment.get("hookName")), content)
    else:
        _ = record.pop("rendered", None)
    return True


def hung_on(records: list[dict[str, object]], record: dict[str, object]) -> bool:
    """Say whether another record names this one as its parent or as the leaf of the session."""
    uuid = record.get("uuid")
    if not isinstance(uuid, str):
        return True
    links = ("parentUuid", "logicalParentUuid", "leafUuid")
    return any(other.get(link) == uuid for other in records for link in links)


def describe(output: Output) -> str:
    """Return what a hook printed, as one line for a finding."""
    printed = (output.stdout or output.stderr).strip().splitlines()
    first = printed[0] if printed else ""
    return f"exits {output.code} and prints {json.dumps(first[:100])}"


def reconcile(
    records: list[dict[str, object]],
    indices: list[int],
    outputs: list[Output],
    command: str,
    event: Event,
) -> tuple[list[Finding], set[int]]:
    """Bring the records of one command in one event up to date, and return what was behind and the records to delete.

    Changes in place each record that it can bring up to date.
    """
    printing = [output for output in outputs if not output.silent]
    unheld = list(range(len(printing)))
    stale: list[int] = []
    for index in indices:
        held = next((number for number in unheld if holds(records[index], printing[number])), None)
        if held is None:
            stale.append(index)
        else:
            unheld.remove(held)
    label = f"{command} on {event.name}" + (f":{event.matched}" if event.matched else "")
    if not unheld:
        findings: list[Finding] = []
        for index in stale:
            kept = hung_on(records, records[index])
            reason = ", and records hang off this one" if kept else ""
            message = f"{label} prints nothing at head that this record holds{reason}"
            findings.append(Finding(index + 1, message, None if kept else "deleted"))
        return findings, {finding.line - 1 for finding in findings if finding.action == "deleted"}
    if len(stale) == len(unheld):
        findings = []
        for index, number in zip(stale, unheld, strict=True):
            output = printing[number]
            fixed = rewrite(records[index], output)
            kind = table(records[index].get("attachment"), "a hook record").get("type")
            reason = "" if fixed else f", which the program cannot write into a record of type {kind}"
            findings.append(
                Finding(index + 1, f"{label} {describe(output)} at head{reason}", "rewritten" if fixed else None)
            )
        return findings, set()
    line = (stale or indices)[0] + 1
    message = f"{label}: {len(stale)} records are behind, and {len(unheld)} hooks print at head what no record holds"
    return [Finding(line, message, None)], set()


def dumps(record: dict[str, object]) -> str:
    """Return a record as one line of a transcript, as Claude Code writes it."""
    return json.dumps(record, ensure_ascii=False, separators=(",", ":"))


def update(history: pathlib.Path, hooks: list[Hook], replayer: Replayer) -> tuple[list[str], list[Finding]]:
    """Return the lines of a history brought up to date, and what was behind in it."""
    lines = history.read_text(encoding="utf-8").splitlines()
    records = [table(t.cast("object", json.loads(line)), f"{history}:{number}") for number, line in enumerate(lines, 1)]
    before = [dumps(record) for record in records]
    events: dict[tuple[str, str], dict[str, list[int]]] = {}
    for index, record in enumerate(records):
        where = f"{history}:{index + 1}"
        attachment = attachment_of(record)
        if attachment is None:
            continue
        if attachment.get("type") not in HOOK_RECORDS:
            raise HistoryError(f"{where}: the program cannot replay a record of type {attachment.get('type')}")
        key = (text(attachment.get("hookEvent"), f"{where}: hookEvent"), str(attachment.get("toolUseID")))
        events.setdefault(key, {}).setdefault(command_of(attachment, where), []).append(index)
    findings: list[Finding] = []
    deleted: set[int] = set()
    for commands in events.values():
        first = min(index for indices in commands.values() for index in indices)
        event = event_of(records, records[first], f"{history}:{first + 1}")
        for command, indices in commands.items():
            matching = [hook for hook in hooks if hook.event == event.name and hook.command == command]
            outputs = [replayer.run(hook, event) for hook in matching if hook.matches(event.matched)]
            found, deletable = reconcile(records, indices, outputs, command, event)
            findings.extend(found)
            deleted |= deletable
    updated = [
        line if (after := dumps(record)) == old else after
        for line, record, old in zip(lines, records, before, strict=True)
    ]
    kept = [line for index, line in enumerate(updated) if index not in deleted]
    return kept, sorted(findings, key=lambda finding: finding.line)


def toplevel() -> pathlib.Path:
    """Return the root of the working tree around the working directory."""
    result = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise HistoryError(f"no git working tree holds {pathlib.Path.cwd()}: {result.stderr.strip()}")
    return pathlib.Path(result.stdout.strip())


def main() -> None:
    """Update or check every history of the checkout, and exit 1 when one is behind or needs a new recording."""
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0] if __doc__ else None)
    _ = parser.add_argument("--check", action="store_true", help="change nothing, and exit 1 when a history is behind")
    _ = parser.add_argument("root", nargs="?", type=pathlib.Path, help="the checkout, by default the working tree")
    arguments = parser.parse_args()
    check = t.cast("bool", arguments.check)
    given_root = t.cast("pathlib.Path | None", arguments.root)
    try:
        root = (given_root or toplevel()).resolve()
        hooks = registered_hooks(root)
        failed = False
        with tempfile.TemporaryDirectory() as scratch:
            replayer = Replayer(root, pathlib.Path(scratch).resolve())
            for history in histories(root):
                lines, findings = update(history, hooks, replayer)
                shown = history.relative_to(root)
                for finding in findings:
                    if check:
                        print(f"{shown}:{finding.line}: behind: {finding.message}", file=sys.stderr)
                    elif finding.action is not None:
                        print(f"{shown}:{finding.line}: {finding.action}: {finding.message}")
                    else:
                        print(f"{shown}:{finding.line}: record the session again: {finding.message}", file=sys.stderr)
                failed |= bool(findings) if check else any(finding.action is None for finding in findings)
                if findings and not check:
                    _ = history.write_text("".join(f"{line}\n" for line in lines), encoding="utf-8")
    except HistoryError as error:
        sys.exit(f"update-eval-histories: {error}")
    if failed and check:
        sys.exit("update-eval-histories: a history records what its hooks no longer print; run update-eval-histories")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
