# Load a package's intent: design

The design of [Load a package's INTENT.md into context when an agent works on the package](https://github.com/lyngon/devkit/issues/16), settled with the owner in an interview on 2026-11-10.
It is transient, and the last commit of the change removes it.

## Goal

An agent that works on a package has that package's `INTENT.md` in its context without being told to read it, and an agent that works on nothing of the package does not carry it.

Done means:

- In a scratch repository with a package that has its own `INTENT.md`, a headless session that reads or edits a file of that package can quote the package's intent word for word, without having been asked to read it.
- The same holds after a compaction: the intent is back word for word before the first read or change of a file in the package after it.
- A session that touches no file of the package does not carry its intent.
- `repo:add-package` writes what the mechanism needs, and `conventions:documents` and `validate-documents` agree with it.
- A headless session in a clone of `lyngon/lyngon.com`, with this branch's plugins, quotes the intent of `tools/check-backends` after editing a file there, and does not carry it when it touches no package.

Working on a package means the file tools: Read, Edit and Write.
A package that an agent only changes through the shell, or only searches with Grep and Glob, does not load its intent.

## Approach

A package with its own `INTENT.md` holds an agent file, `<package>/.claude/CLAUDE.md`, the same shape as the root's.
Claude Code loads a nested agent file and its imports as soon as a file below its directory is read, written or edited, so the package's intent arrives as project instructions when an agent works on the package.

Every agent file, the root's and a package's, holds only import lines:

- Each non-blank line has the form `@../<name>.md` and names a tracked Markdown file directly in the directory that holds `.claude/`, such as `INTENT.md`, `CONCEPTS.md` or `README.md`.
- The line `@../INTENT.md` is required. Other imports are allowed, and nothing writes them by default.
- Free text is not allowed, at the root either. A principle goes to a rule file under `.claude/rules/`, with `paths:` when it concerns part of the tree.
- A package agent file exists only next to a package `INTENT.md`. A context's core library with a `CONCEPTS.md` and no `INTENT.md` gets none, and its glossary stays on demand.

| Decision | Chosen | Rejected, and why |
| --- | --- | --- |
| The mechanism | A package agent file that imports the intent | A hook in the `repo` plugin: it would close the two gaps under "Facts", but needs per-session state of which agent already holds which intent, and its text arrives as hook context, for loading that Claude Code already does. A rule file at the root, scoped to the package, that imports the intent: Claude Code loads the import at launch, whatever the rule's `paths:` say. |
| Where the file lives | `<package>/.claude/CLAUDE.md`, holding `@../INTENT.md` | `<package>/CLAUDE.md`, holding `@INTENT.md`: it loads the same way, but breaks the owner's ruling on pull request 15 that a `CLAUDE.md` lives only inside `.claude/`, and has another shape than the root's. |
| What an agent file holds | Only imports of its own directory's top-level Markdown files, `@../INTENT.md` among them | Free text, as the root allowed until now: a second home for rules beside `.claude/rules/`. Any file below the directory: the root could load a package's files into every session. |
| Where it is enforced | `validate-documents`, so an `INTENT.md` written by hand gets its agent file too | `repo:add-package` alone: an author who adds an intent later would have to remember the file. |

## Facts

Measured on 2026-11-10 with headless sessions in scratch repositories, on Claude Code 2.1.283 (the Nix CLI) and 2.1.319 (the extension), and read from the transcripts' attachments, not only from the model's answers.

- A package's `CLAUDE.md`, `.claude/CLAUDE.md` or `.claude/rules/<name>.md` loads, with its import, after the first read of a file in the package, in the lead and in a subagent. Nothing loads before, and nothing in a session that never touches the package.
- A write of a new file in a package loads it on 2.1.299, 2.1.311 and 2.1.319, and does not on 2.1.283.
- A compaction drops it. Up to five files read last come back as file attachments, and an `INTENT.md` among them comes back word for word. The next read, write or edit of a file in the package loads it again.
- After a compaction, 2.1.283 refuses an edit of a file until it is read again, and 2.1.319 accepts the edit and loads the intent with it. So no change to a package happens without its intent, on either version.
- A rule file under `.claude/rules/` with `paths:` loads only after a matching file is read, but a file it imports with `@` loads at launch.

## Components

- `validate-documents` and its fixture tests:
  - `no-claude-md-outside-dot-claude` fails a `CLAUDE.md` whose directory is not a `.claude/`.
  - `agent-file-imports-intent` fails a root agent file that is missing, untracked or lacks the line, as today. It also fails a package `INTENT.md` without a tracked agent file beside it, and a package agent file without the line.
  - A new rule, `agent-file-holds-only-imports`, fails a line of an agent file that is not an import of a tracked Markdown file directly in its directory. Its message says where the text goes instead.
  - The pair of a package `INTENT.md` and its agent file is checked when either is among the arguments, deleted or not, so a fixture tree stays out through the hook's `excludes`.
- The baseline excludes every agent file from markdownlint, `(^|/)\.claude/CLAUDE\.md$`, and the devkit's `devenv.nix` and init's devenv reference repeat the pattern.
- `conventions:documents`: the table row of the agent file and of `CONCEPTS.md`, the rules, the section "Package documents", and `paths:` covering `**/.claude/CLAUDE.md`.
- `repo:add-package`: step 5 writes `<package>/.claude/CLAUDE.md` with `@../INTENT.md` whenever it writes the package's `INTENT.md`, and the template is in `references/package-files.md`.
- `repo:init`: the agent file template says it holds only imports. In adopt mode, what the owner wants kept from an old `CLAUDE.md` goes into a rule file, never into the agent file. A package with an `INTENT.md` gets its agent file, and a package `CLAUDE.md` is sorted like the root's.
- `shared/STRUCTURE.md` and the example tree in `README.md` show the package agent file.
- An eval case for `repo:add-package` that writes a package with its own intent, graded on the agent file's content.
- The decision record [a-package-agent-file-loads-the-package-intent.md](../decisions/a-package-agent-file-loads-the-package-intent.md) and the term **Agent file** in `CONCEPTS.md`, both on this branch already.

Outside this change, each on its own:

- An issue on `lyngon/lyngon.com`: once it takes the merged baseline, `validate-documents` fails its four package intents until each has its agent file.
- A pull request of its own: `validate-documents` fails a rule file with `paths:` that imports with `@`, because the import defeats the scope.
- A draft upstream report on the import that a scoped rule loads at launch, in the main checkout's `tmp/`.

## Proof owed

- `devenv test` passes, with a fixture test for each message of the three rules that fails at the base and passes at head.
- A headless run, on 2.1.283 and 2.1.319, in a scratch repository built from what `repo:add-package` writes. The session quotes the package intent word for word after reading a file of the package and not before. After a compaction, and then an edit of a file in the package, it quotes it again. A second session that reads only files at the root never carries it. The transcript's attachments back each answer.
- In a clone of `lyngon/lyngon.com` at its `main`: this branch's `validate-documents` names the four missing agent files, and passes once they are added as its messages say. A headless session with this branch's plugins edits a file of `tools/check-backends` and then quotes its intent, and a session that edits only a file at the root does not carry it.
- The eval suite's score for `repo` at the base and at head, from `compare-evals`.

## Validator sketch

The shape of the agent-file rules in `devenv/validate-documents.py`, synthesized by `build:architect` from two candidates through `build:arena`.

### Usage

```sh
validate-documents libs/orders/INTENT.md
```

```sh
validate-documents
```

The first is the pre-commit hook: every path given, deleted or not, brings in the agent file of its own directory, so deleting either half of a package's pair, or a file its agent file imports, fails the commit, and a fixture tree that a hook's `excludes` keeps out of the arguments brings nothing in.
The second checks every tracked file.
A run without git (python3 alone on the PATH) counts every file of the working tree as tracked.

### Shape

- `AgentFile(home)`, a frozen dataclass, is the place `<home>/.claude/CLAUDE.md`, whether the file exists or not; the root is `PurePosixPath(".")`.
  Its members `path`, `intent`, `sibling(name)`, `is_root` and `place` (`the root` or `libs/orders/`) are the only code that joins `.claude`, `CLAUDE.md` or `INTENT.md` onto a directory.
- `agent_file_of(path) -> AgentFile | None`: the inverse, `<home>/.claude/CLAUDE.md` gives `AgentFile(home)`.
- The line grammar, in constants and one parse: `IMPORT = @../(?P<name>[^/\s]+\.md)`, `ANY_IMPORT = \s*@\S+`, each matched in full against the line with trailing whitespace removed; a line is `Import(number, name)`, `ImportElsewhere(number, text)` or `Text(number)`, and a blank line is none of them. The checks match the union with `assert_never`.
- `Tree(root, tracked)`, read once at the boundary by `read_tree`, which replaces `files_to_check` with the same root and refusals and runs one `git ls-files -z`; `tracked is None` when git cannot say. `Tree.holds(path)` is the one meaning of "missing or untracked".
- `skipped(path)`: the vendor and generated skip, used by both passes.
- `agent_files(paths) -> list[AgentFile]`, pure: the root's, plus for every path that is not skipped `agent_file_of(path)` or `AgentFile(path.parent)`, unique, root first.
- `check_agent_file(tree, agent_file) -> list[str]`: the only function that prints for `agent-file-imports-intent` and `agent-file-holds-only-imports`.
- `check(tree, paths)`: first `check_agent_file` for each of `agent_files(paths)`, then the per-path loop of today, whose `CLAUDE.md` condition becomes `path.name == "CLAUDE.md" and agent_file_of(path) is None`. `main` loses its separate call for the root's agent file.

`check_agent_file` asks `there = tree.holds(path)` (an unreadable file counts as not there) and `intent = tree.holds(intent)`:

| Place | there | intent | Messages |
| --- | --- | --- | --- |
| root | no | either | A-create, and A-root-intent when no intent |
| root | yes | no | A-root-intent, then the lines |
| root | yes | yes | the lines |
| package | no | no | nothing: no package here |
| package | no | yes | A-create |
| package | yes | no | A-package-intent, then the lines |
| package | yes | yes | the lines |

The lines: each `Text` gives H-text, each `ImportElsewhere` H-elsewhere, each `Import` of a name other than `INTENT.md` whose sibling the tree does not hold H-untracked, and no `Import` of `INTENT.md` gives A-add-line, at the root or where the intent is held.
The target of `@../INTENT.md` belongs to the pair, so a missing intent is reported once.

### Messages, word for word

With `libs/orders` as the package:

```text
A-create        error: .claude/CLAUDE.md: agent-file-imports-intent: create it with the line @../INTENT.md, so that every session starts from the intent
                error: libs/orders/.claude/CLAUDE.md: agent-file-imports-intent: create it with the line @../INTENT.md, so that a session loads the package's intent when it works on a file in libs/orders/
A-add-line      error: .claude/CLAUDE.md: agent-file-imports-intent: add the line @../INTENT.md, so that every session starts from the intent
                error: libs/orders/.claude/CLAUDE.md: agent-file-imports-intent: add the line @../INTENT.md, so that a session loads the package's intent when it works on a file in libs/orders/
A-root-intent   error: INTENT.md: agent-file-imports-intent: create it with the repository's intent, which .claude/CLAUDE.md imports into every session
A-package-intent error: libs/orders/INTENT.md: agent-file-imports-intent: create it with the sections in which the package's intent differs from the root's, or delete libs/orders/.claude/CLAUDE.md, which a package holds only beside its INTENT.md
H-text          error: .claude/CLAUDE.md:3: agent-file-holds-only-imports: delete the line, or move what it says to .claude/rules/<principle>.md, with paths: when it concerns part of the tree; an agent file holds only lines of the form @../<name>.md
H-elsewhere     error: libs/orders/.claude/CLAUDE.md:2: agent-file-holds-only-imports: '@../../INTENT.md' imports no Markdown file directly in libs/orders/; write it as @../<name>.md, or delete the line
H-untracked     error: libs/orders/.claude/CLAUDE.md:2: agent-file-holds-only-imports: the line imports libs/orders/NOTES.md, which is missing or untracked; add the file, or delete the line
stray CLAUDE.md error: CLAUDE.md: no-claude-md-outside-dot-claude: move what must stay to .claude/rules/<principle>.md, with paths: when it concerns part of the tree, and delete the file
AGENTS.md       error: AGENTS.md: no-agents-md: move what must stay to .claude/rules/<principle>.md, with paths: when it concerns part of the tree, and delete the file; Claude Code reads .claude/CLAUDE.md, and no other agent harness is supported
```

The root's H-elsewhere names `the root` where a package's names its directory.

### Fixtures

`clean_repo` gets a root agent file of import lines only (`@../INTENT.md`, `@../CONCEPTS.md`) and `libs/orders/.claude/CLAUDE.md` holding `@../INTENT.md`, a blank line and `@../README.md`.
Each message above gets a fixture at the root and in a package where both apply, and these cases get one each:

- A deleted package agent file, a deleted package `INTENT.md` and a deleted imported file, each given as the only argument.
- Both halves of a pair given, one of them deleted: one error.
- A stray `CLAUDE.md` that the agent file imports, deleted and given as the argument: H-untracked.
- A fixture tree with an `INTENT.md` and no agent file, kept out by the arguments: `ok`; with no arguments: A-create.
- A file deeper in a package given as the argument, with free text in the package's agent file: `ok`.
- `vendor/` and `generated/` directories holding an `INTENT.md` and an agent file with free text: `ok`.
- An indented `@../INTENT.md`, a name with a space, `@anders please review` (H-text), an import of `ruff.toml`, `@INTENT.md`.
- A context's core library with a `CONCEPTS.md` and an agent file that imports only it: A-package-intent.
- The run without git: a directory that is no repository, with python3 alone on the PATH.

The test "the import may stand anywhere in the file" goes, and the test of a `.claude` directory below the root turns into a passing package.
`plugins/build/tests/prune-mistakes.sh` writes an `INTENT.md` into its fixture repository.

### Synthesis decision

Candidate 2 (the role of each path) is the base, on the judge's scores of 23 to 21 and its smaller surface: an agent file as a place needs no second code path for a missing file, and one function prints both rules.
From candidate 1 (the directory model) came the typed line grammar, the pair's ownership of the intent line, and the separate pass before the per-path loop.
Two fixes closed defects that the judge found in the base: every path, not only a Markdown file, brings in its directory's agent file, and only trailing whitespace is forgiven on a line.
Rejected: candidate 1's load before deciding what to check, since a directory with neither half gives no message anyway, and candidate 2's agent files inside the per-path loop.

### Tradeoffs accepted

- We accept two file lookups for the directory of every path in a run, most of them no package, in exchange for a rule with no notion of a package beyond its two files.
- We accept one `git ls-files -z` per run, with arguments too, in exchange for one definition of tracked.
- We accept that an empty repository reports two errors, the agent file and the intent, in exchange for one rule for the root's pair.
- We accept one error per line of free text, in exchange for a line number on each.
