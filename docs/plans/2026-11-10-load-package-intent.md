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
