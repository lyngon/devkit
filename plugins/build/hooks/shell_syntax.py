# ruff: noqa: INP001  # a module beside the hook scripts that import it, which no package holds
"""The simple commands and redirections of a shell command."""

import collections
import collections.abc as ct
import dataclasses
import json
import pathlib
import re
import subprocess
import typing as t


class ParserMissingError(Exception):
    """shfmt, which parses a command, is not on the PATH."""


@dataclasses.dataclass(frozen=True, slots=True)
class Word:
    """A word of a shell command: its literal start, up to the first expansion, whether that is all, and its text.

    A word in double quotes and the body of a here-document, which the shell expands without splitting, also have
    their text unexpanded: without the backslashes that only quote, and with each expansion as written.
    """

    start: str
    complete: bool = True
    text: str = dataclasses.field(default="", kw_only=True)
    unexpanded: str | None = dataclasses.field(default=None, kw_only=True)

    @property
    def value(self) -> str | None:
        """Return the whole word, or None when an expansion decides part of it as the command runs."""
        return self.start if self.complete else None


UNSEEN = Word("", complete=False)


@dataclasses.dataclass(frozen=True, slots=True)
class Call:
    """A simple command: its words, the first its name, its text in the command, and its standard input.

    Its standard input is the text of a here-document or a here-string, as a word, the simple command that writes to
    it through a pipe, or None for anything else: a file, a compound command, or the input of the whole command.
    """

    words: tuple[Word, ...]
    text: str
    standard_input: "Word | Call | None" = None


@dataclasses.dataclass(frozen=True, slots=True)
class Redirection:
    """A redirection: its operator, the word it redirects to, and its text in the command."""

    operator: str
    target: Word
    text: str


SIMPLE_EXPANSION = frozenset({"Type", "Pos", "End", "Dollar", "Rbrace", "Short", "Param"})

DOUBLE_QUOTED = re.compile(r'"((?:[^"\\]|\\.)*)"', re.DOTALL)

QUOTES = re.compile(r"[\\'\"]")

ESCAPED_IN_A_HERE_DOCUMENT = re.compile(r"\\(?:([\\`$])|\n)")


def objects(value: object) -> list[dict[str, object]]:
    """Return the JSON objects that a value of the syntax tree holds: itself, or the items of a list."""
    items = t.cast("list[object]", value) if isinstance(value, list) else [value]
    return [t.cast("dict[str, object]", item) for item in items if isinstance(item, dict)]


def offset(node: dict[str, object], key: str) -> int:
    """Return the byte offset of a position of a node of the syntax tree."""
    position = objects(node.get(key))
    value = position[0].get("Offset") if position else None
    return value if isinstance(value, int) else 0


def string_field(node: dict[str, object], key: str) -> str:
    """Return a string field of a node of the syntax tree, or an empty one."""
    value = node.get(key)
    return value if isinstance(value, str) else ""


def name_of(node: dict[str, object]) -> str:
    """Return the name that a node of the syntax tree gives in its Name or Param field, or an empty one."""
    names = objects(node.get("Name", node.get("Param")))
    return string_field(names[0], "Value") if names else ""


def expanded(part: dict[str, object], variables: ct.Mapping[str, str]) -> str | None:
    """Return the value of a part of a word that expands a variable of variables plainly, as $T or ${T}, or None."""
    if string_field(part, "Type") != "ParamExp" or not part.keys() <= SIMPLE_EXPANSION:
        return None
    return variables.get(name_of(part))


def word(node: dict[str, object], source: bytes, variables: ct.Mapping[str, str]) -> Word:
    """Return the word that a Word node of the syntax tree stands for, with the variables of variables expanded."""
    text = source[offset(node, "Pos") : offset(node, "End")].decode()
    quoted = DOUBLE_QUOTED.fullmatch(text)
    unexpanded = None if quoted is None else re.sub(r"\\([\\\"`$])", r"\1", quoted.group(1))
    start = ""
    for part in objects(node.get("Parts")):
        match string_field(part, "Type"):
            case "Lit":
                start += re.sub(r"\\(.)", r"\1", string_field(part, "Value"), flags=re.DOTALL)
            case "SglQuoted":
                start += string_field(part, "Value")
            case "DblQuoted":
                for inner in objects(part.get("Parts")):
                    value = string_field(inner, "Value") if string_field(inner, "Type") == "Lit" else None
                    value = expanded(inner, variables) if value is None else value
                    if value is None:
                        return Word(start, complete=False, text=text, unexpanded=unexpanded)
                    start += value
            case _ if (value := expanded(part, variables)) is not None:
                start += value
            case _:
                return Word(start, complete=False, text=text, unexpanded=unexpanded)
    return Word(start, text=text, unexpanded=unexpanded)


def here_document(redirect: dict[str, object], source: bytes, variables: ct.Mapping[str, str]) -> Word:
    """Return the body of the here-document that a Redirect node of the syntax tree opens, as a word.

    The shell expands nothing in the body when any of the word that ends it is quoted. Otherwise it expands the body as
    a word in double quotes, except that a backslash before a double quote stays.
    """
    bodies = objects(redirect.get("Hdoc"))
    parts = objects(bodies[0].get("Parts")) if bodies else []
    ending = objects(redirect.get("Word"))[0]
    if QUOTES.search(source[offset(ending, "Pos") : offset(ending, "End")].decode()):
        body = "".join(string_field(part, "Value") for part in parts)
        return Word(body, unexpanded=body)
    start, complete, unexpanded = "", True, ""
    for part in parts:
        if string_field(part, "Type") == "Lit":
            text = value = ESCAPED_IN_A_HERE_DOCUMENT.sub(r"\1", string_field(part, "Value"))
        else:
            text, value = source[offset(part, "Pos") : offset(part, "End")].decode(), expanded(part, variables)
        unexpanded += text
        if complete and value is not None:
            start += value
        else:
            complete = False
    return Word(start, complete=complete, unexpanded=unexpanded)


def nodes_in_order(tree: object) -> ct.Iterator[dict[str, object]]:
    """Yield the nodes of the syntax tree in the order of their text in the command."""
    pending = objects(tree)
    while pending:
        node = pending.pop()
        yield node
        pending.extend(reversed([item for value in node.values() for item in objects(value)]))


def literal_variables(nodes: ct.Sequence[dict[str, object]], source: bytes) -> dict[str, str]:
    """Return the variables that a command assigns once, each to a value without an expansion, with their values.

    A loop variable, a variable assigned twice and an array take more than one value, so none of them is returned.
    """
    assignments = [node for node in nodes if "Name" in node and "Type" not in node]
    loops = [node for node in nodes if string_field(node, "Type") == "WordIter"]
    counts = collections.Counter(name_of(node) for node in [*assignments, *loops, *loops])
    variables: dict[str, str] = {}
    for assignment in assignments:
        values = objects(assignment.get("Value"))
        if counts[name_of(assignment)] == 1 and values and not assignment.get("Append"):
            value = word(values[0], source, variables).value
            if value is not None:
                variables[name_of(assignment)] = value
    return variables


def calls_and_redirections(
    command: str, dialects: ct.Sequence[str] = ("bash",), *, resolve_variables: bool = False
) -> list[Call | Redirection] | None:
    """Return the simple commands and redirections of a shell command, or None when it parses in none of the dialects.

    Each dialect is a language of shfmt, tried in turn. With resolve_variables, a plain expansion of a variable that
    the command assigns once, to a value without an expansion, stands for that value.
    Raises ParserMissingError when shfmt is not on the PATH.
    """
    parsed = None
    for dialect in dialects:
        try:
            parsed = subprocess.run(
                ["shfmt", "--language-dialect", dialect, "--to-json"],
                input=command.encode(),
                capture_output=True,
                check=False,
            )
        except FileNotFoundError as error:
            raise ParserMissingError from error
        if parsed.returncode == 0:
            break
    if parsed is None or parsed.returncode != 0:
        return None
    tree = SyntaxTree(
        command.encode(), t.cast("object", json.loads(parsed.stdout)), resolve_variables=resolve_variables
    )
    found: list[Call | Redirection] = []
    for node in tree.nodes:
        call = tree.simple_command(node)
        if call is not None:
            found.append(call)
        for redirect in objects(node.get("Redirs")):
            target = objects(redirect.get("Word"))
            if target:
                span = tree.source[offset(redirect, "Pos") : offset(redirect, "End")].decode()
                found.append(Redirection(tree.operator(redirect), word(target[0], tree.source, tree.variables), span))
    return found


@t.final
class SyntaxTree:
    """The syntax tree of a command that shfmt parsed: its nodes in order, and what each simple command reads."""

    def __init__(self, source: bytes, tree: object, *, resolve_variables: bool) -> None:
        self.source: bytes = source
        self.nodes: list[dict[str, object]] = list(nodes_in_order(tree))
        self.variables: ct.Mapping[str, str] = literal_variables(self.nodes, source) if resolve_variables else {}
        self.writers: dict[int, dict[str, object]] = {
            id(objects(node.get("Y"))[0]): objects(node.get("X"))[0] for node in self.nodes if self.pipes(node)
        }

    def pipes(self, node: dict[str, object]) -> bool:
        """Return whether a node is a pipe, | or |&, from the output of its statement X to the input of its Y."""
        position = offset(node, "OpPos")
        return (
            string_field(node, "Type") == "BinaryCmd"
            and self.source.startswith(b"|", position)
            and not self.source.startswith(b"||", position)
        )

    def operator(self, redirect: dict[str, object]) -> str:
        """Return the operator of a Redirect node, such as > or <<<, without the number of a file descriptor."""
        target = objects(redirect.get("Word"))
        return self.source[offset(redirect, "OpPos") : offset(target[0], "Pos")].decode().strip() if target else ""

    def simple_command(self, statement: dict[str, object]) -> Call | None:
        """Return the simple command of a Stmt node, with its standard input, or None for any other node."""
        commands = objects(statement.get("Cmd"))
        if not commands or string_field(commands[0], "Type") != "CallExpr":
            return None
        words = tuple(word(argument, self.source, self.variables) for argument in objects(commands[0].get("Args")))
        text = self.source[offset(commands[0], "Pos") : offset(commands[0], "End")].decode()
        return Call(words, text, self.standard_input(statement))

    def standard_input(self, statement: dict[str, object]) -> Word | Call | None:
        """Return the standard input of the simple command of a Stmt node, as Call.standard_input describes it."""
        redirects = [redirect for redirect in objects(statement.get("Redirs")) if self.redirects_input(redirect)]
        if not redirects:
            writer = self.writers.get(id(statement))
            return None if writer is None else self.simple_command(writer)
        match self.operator(redirects[-1]):
            case "<<<":
                return word(objects(redirects[-1].get("Word"))[0], self.source, self.variables)
            case "<<" | "<<-":
                return here_document(redirects[-1], self.source, self.variables)
            case _:
                return None

    def redirects_input(self, redirect: dict[str, object]) -> bool:
        """Return whether a Redirect node redirects standard input, file descriptor 0."""
        numbers = objects(redirect.get("N"))
        return string_field(numbers[0], "Value") == "0" if numbers else self.operator(redirect).startswith("<")


def command_name(value: str | None) -> str | None:
    """Return the name of the command that a word names, without its directory."""
    return None if value is None else pathlib.PurePath(value).name


class UnreadableError(Exception):
    """A command holds a construct whose extent may_run cannot tell. The message names it, as a clause."""


OPERATORS = re.compile(r";;&|;;|;&|&&|\|\||\|&|&>>|&>|>>|>\||>&|<<<|<<-|<<|<>|<&|\(\(|[;&|()<>\n]")

REDIRECTIONS = frozenset({"<", ">", ">>", ">|", "&>", "&>>", "<>", "<<<", ">&", "<&", "<<", "<<-"})

HERE_DOCUMENTS = frozenset({"<<", "<<-"})

WORD_ENDS = frozenset(" \t\n;&|()<>")

BLANKS = (" ", "\t", "\\\n")

ESCAPED_IN_DOUBLE_QUOTES = frozenset({"$", "`", '"', "\\"})

PARAMETER = re.compile(r"[A-Za-z_][A-Za-z0-9_]*|[0-9@*#?$!-]")

PLAIN_EXPANSION = re.compile(r"\$(?:\{(?P<braced>[A-Za-z_][A-Za-z0-9_]*)\}|(?P<bare>[A-Za-z_][A-Za-z0-9_]*))")

ENDS_A_BARE_EXPANSION_IN_BASH_AND_ZSH = WORD_ENDS | {"/", '"'}

ARITHMETIC = "an arithmetic expression"

EXPRESSIONS = {"$((": ("))", ARITHMETIC), "$[": ("]", ARITHMETIC), "${": ("}", "a ${...}")}


@dataclasses.dataclass(frozen=True, slots=True)
class HereDocument:
    """A here-document whose body starts on the next line: the line that ends it, and how its body reads."""

    delimiter: str
    expands: bool
    strips_tabs: bool


def line_end(source: str, index: int) -> int:
    """Return the index of the newline that ends the line at index, or the length of the source."""
    end = source.find("\n", index)
    return len(source) if end < 0 else end


def unescaped(source: str, index: int, char: str) -> int:
    """Return the index of the first char at or after index that no backslash escapes. Raises UnreadableError."""
    while index < len(source):
        if source[index] == char:
            return index
        index += 2 if source[index] == "\\" else 1
    raise UnreadableError(f"a {char} is not closed")


@t.final
class CommandReader:
    """Reads a command from left to right, and keeps each simple command and redirection that it may run."""

    def __init__(self, source: str, variables: ct.Mapping[str, str]) -> None:
        self.source: str = source
        self.variables: ct.Mapping[str, str] = variables
        self.found: list[Call | Redirection] = []
        self.here_documents: list[HereDocument] = []

    def commands(self, index: int, closer: str | None) -> int:
        """Read the commands from index up to the closer, or to the end without one, and return the index after it."""
        source = self.source
        words: list[tuple[Word, int, int]] = []
        while index < len(source):
            if source[index] == "#":
                index = line_end(source, index)
            elif source.startswith(BLANKS, index):
                index += 2 if source[index] == "\\" else 1
            elif (operator := self.operator(index)) is None:
                index = self.command_word(index, words, closer)
            elif operator.group() in REDIRECTIONS:
                index = self.redirection(operator)
            elif operator.group() == ")" and closer == ")":
                self.simple_command(words)
                return index + 1
            else:
                self.simple_command(words)
                index = self.after_operator(operator)
        if closer is not None:
            raise UnreadableError("a parenthesis is not closed")
        self.simple_command(words)
        if self.here_documents:
            raise UnreadableError(f"no line {self.here_documents[0].delimiter} ends its here-document")
        return index

    def operator(self, index: int) -> re.Match[str] | None:
        """Return the operator at index, or None where a word starts, a process substitution included."""
        return None if self.source.startswith(("<(", ">("), index) else OPERATORS.match(self.source, index)

    def command_word(self, index: int, words: list[tuple[Word, int, int]], closer: str | None) -> int:
        """Read a word of a simple command into its words, and return the index after it."""
        begin = index
        word, quoted, index = self.word(index)
        if self.names_a_file_descriptor(word, index, quoted=quoted):
            return index
        if closer == ")" and word.value == "case":
            raise UnreadableError("it holds a case statement inside parentheses")
        words.append((word, begin, index))
        return index

    def names_a_file_descriptor(self, word: Word, end: int, *, quoted: bool) -> bool:
        """Return whether a word ending at end numbers the file descriptor of the redirection right after it, as 2>x."""
        return not quoted and (word.value or "").isdigit() and self.source.startswith(("<", ">"), end)

    def redirection(self, operator: re.Match[str]) -> int:
        """Keep the redirection of an operator and the word after it, and the here-document it opens.

        Returns the index after the word.
        """
        source = self.source
        index = operator.end()
        while source.startswith(BLANKS, index):
            index += 2 if source[index] == "\\" else 1
        if index >= len(source) or self.operator(index) is not None:
            raise UnreadableError(f"`{operator.group()}` has no word after it")
        reader = CommandReader(source, {}) if operator.group() in HERE_DOCUMENTS else self
        target, quoted, end = reader.word(index)
        if operator.group() in HERE_DOCUMENTS:
            if target.value is None:
                raise UnreadableError("the word that ends a here-document holds an expansion")
            strips_tabs = operator.group() == "<<-"
            self.here_documents.append(HereDocument(target.value, expands=not quoted, strips_tabs=strips_tabs))
        self.found.append(Redirection(operator.group(), target, source[operator.start() : end]))
        return end

    def after_operator(self, operator: re.Match[str]) -> int:
        """Read what an operator that ends a simple command opens, and return the index after it."""
        match operator.group():
            case "((":
                return self.expression(operator.end(), "))", ARITHMETIC)
            case "(":
                return self.commands(operator.end(), ")")
            case "\n":
                return self.here_document_bodies(operator.end())
            case _:
                return operator.end()

    def simple_command(self, words: list[tuple[Word, int, int]]) -> None:
        """Keep a simple command, also from each of its later words on, and empty the words for the next one."""
        for first, (_, begin, _) in enumerate(words):
            self.found.append(Call(tuple(word for word, _, _ in words[first:]), self.source[begin : words[-1][2]]))
        words.clear()

    def here_document_bodies(self, index: int) -> int:
        """Read the bodies of the here-documents that start at index, and return the index after them."""
        source = self.source
        while self.here_documents:
            document = self.here_documents.pop(0)
            while True:
                if index >= len(source):
                    raise UnreadableError(f"no line {document.delimiter} ends its here-document")
                line = source[index : line_end(source, index)]
                if (line.lstrip("\t") if document.strips_tabs else line) == document.delimiter:
                    index += len(line) + 1
                    break
                index = self.expansions_of_line(index) if document.expands else index + len(line) + 1
        return index

    def expansions_of_line(self, index: int) -> int:
        """Read the expansions of a line of a here-document's body, and return the index of the next line."""
        source = self.source
        while index < len(source) and source[index] != "\n":
            if source[index] == "\\":
                index += 2
            elif source[index] in "$`" and (after := self.expansion(index)) is not None:
                index = after
            else:
                index += 1
        return index + 1

    def word(self, index: int) -> tuple[Word, bool, int]:
        """Read the word that starts at index: return it, whether any of it is quoted, and the index after it."""
        source = self.source
        word_start, literal, complete, quoted = index, "", True, False
        while index < len(source):
            char = source[index]
            text, whole = "", True
            if (index == word_start and source.startswith(("<(", ">("), index)) or (index > word_start and char == "("):
                index, whole = self.commands(index + (1 if char == "(" else 2), ")"), False
            elif char in WORD_ENDS:
                break
            elif char in "\\'\"" or source.startswith(("$'", '$"'), index):
                quoted = quoted or not source.startswith("\\\n", index)
                text, whole, index = self.quoted(index)
            elif (known := self.known_variable(index)) is not None:
                text, index = known
            elif char in "$`" and (after := self.expansion(index)) is not None:
                index, whole = after, False
            else:
                text, index = char, index + 1
            if complete:
                literal += text
                complete = whole
        return Word(literal, complete=complete, text=source[word_start:index]), quoted, index

    def quoted(self, index: int) -> tuple[str, bool, int]:
        """Read the quoted text at index: return its literal text up to any expansion, whether it has none, its end."""
        source = self.source
        if source[index] == "\\":
            following = source[index + 1 : index + 2]
            return ("" if following == "\n" else following or "\\"), True, index + 2
        if source[index] == "'":
            end = source.find("'", index + 1)
            if end < 0:
                raise UnreadableError("a ' is not closed")
            return source[index + 1 : end], True, end + 1
        if source.startswith("$'", index):
            end = unescaped(source, index + 2, "'")
            return source[index + 2 : end], True, end + 1
        return self.double_quoted(index + (2 if source[index] == "$" else 1))

    def double_quoted(self, index: int) -> tuple[str, bool, int]:
        """Read a double-quoted text from index: its literal text up to any expansion, whether it has none, its end."""
        source = self.source
        literal, whole = "", True
        while index < len(source):
            char = source[index]
            text = ""
            if char == '"':
                return literal, whole, index + 1
            if char == "\\":
                following = source[index + 1 : index + 2]
                text = following if following in ESCAPED_IN_DOUBLE_QUOTES else char + following
                text = "" if following == "\n" else text
                index += 2
            elif (known := self.known_variable(index)) is not None:
                text, index = known
            elif char in "$`" and (after := self.expansion(index)) is not None:
                index, whole = after, False
            else:
                text, index = char, index + 1
            if whole:
                literal += text
        raise UnreadableError('a " is not closed')

    def known_variable(self, index: int) -> tuple[str, int] | None:
        """Return the value of a plain expansion of a variable of variables at index, and the index after it, or None.

        A plain expansion is ${NAME}, or $NAME before a slash, a double quote or the end of its word, since zsh reads a
        subscript or a modifier right after $NAME, as in $NAME[1] or $NAME:h.
        """
        match = PLAIN_EXPANSION.match(self.source, index)
        if match is None:
            return None
        name = match.group("braced") or match.group("bare")
        ends_bare = match.end() == len(self.source) or self.source[match.end()] in ENDS_A_BARE_EXPANSION_IN_BASH_AND_ZSH
        if name not in self.variables or not (match.group("braced") or ends_bare):
            return None
        return self.variables[name], match.end()

    def expansion(self, index: int) -> int | None:
        """Read the expansion that a $ or a backquote at index starts, and return the index after it.

        Returns None for a $ that expands nothing, before a blank, a double quote or the end of a word.
        """
        source = self.source
        following = source[index + 1 : index + 2]
        opening = next((opening for opening in EXPRESSIONS if source.startswith(opening, index)), None)
        if source[index] == "`":
            return self.backquoted(index + 1)
        if opening is not None:
            return self.expression(index + len(opening), *EXPRESSIONS[opening])
        if following == "(":
            return self.commands(index + 2, ")")
        if following in {"", '"'} or following in WORD_ENDS:
            return None
        name = PARAMETER.match(source, index + 1)
        return index + 1 if name is None else name.end()

    def backquoted(self, index: int) -> int:
        """Read the commands of a backquoted substitution whose text starts at index, and return the index after it."""
        closing_quote = unescaped(self.source, index, "`")
        inner = CommandReader(re.sub(r"\\([\\`$])", r"\1", self.source[index:closing_quote]), self.variables)
        _ = inner.commands(0, None)
        self.found.extend(inner.found)
        return closing_quote + 1

    def expression(self, index: int, closing: str, name: str) -> int:
        """Read an arithmetic expression or a ${...} from index to its closing, and return the index after it."""
        source = self.source
        depth = 0
        while index < len(source):
            char = source[index]
            if depth == 0 and source.startswith(closing, index):
                return index + len(closing)
            if char in "'\"":
                raise UnreadableError(f"{name} holds a quote")
            if char == ")" and depth == 0:
                raise UnreadableError(f"the parentheses of {name} do not match")
            depth += {"(": 1, ")": -1}.get(char, 0)
            if char == "\\":
                index += 2
            elif char in "$`" and (after := self.expansion(index)) is not None:
                index = after
            else:
                index += 1
        raise UnreadableError(f"{name} is not closed")


def named_only_in_plain_expansions(command: str, variables: ct.Mapping[str, str]) -> dict[str, str]:
    """Return the variables of variables that a command names only as $NAME or ${NAME}."""
    return {
        name: value
        for name, value in variables.items()
        if re.search(rf"\b{name}\b", re.sub(rf"\$(?:{name}\b|\{{{name}\}})", "", command)) is None
    }


def may_run(command: str, variables: ct.Mapping[str, str]) -> list[Call | Redirection]:
    """Return the simple commands and redirections that a command may run, read in Python alone.

    The list holds every simple command and every redirection that bash runs for the command, those inside its
    substitutions included, and more: each simple command also from each of its later words on, since a keyword or an
    assignment before the name of a command reads as a word, and a comparison inside [[ ]] reads as a redirection.
    A plain expansion of a variable of variables, which holds its value as the command starts, stands for that value
    where the command names the variable nowhere else.
    Raises UnreadableError, naming the construct, for a command whose structure the reader cannot follow.
    """
    reader = CommandReader(command, named_only_in_plain_expansions(command, variables))
    _ = reader.commands(0, None)
    return reader.found
