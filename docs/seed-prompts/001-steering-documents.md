# Steering documents

Seed prompt for a fresh Claude Code session in the devkit repository.

This is the first of two pull requests that implement one approved design.
Start by asking the owner whether the design is approved, and stop if it is not.
Then implement it in this session: no new design and no plan file, which the owner chose for this program.

## What to read first

- [The design](../plans/2026-10-07-principles-and-steering-documents.md). This pull request covers everything in it except the two sections "The `principles` plugin" and "The `why` skill".
- [The roadmap](../plans/2026-10-07-philosophy-overhaul-roadmap.md), sections "The philosophy" and "Settled for every piece".

## Branch

`feat/steering-documents` exists locally and is not pushed.
It holds the glossary terms, the design, the roadmap and these seed prompts.
Continue on it.

## What must hold when you are done

- Every rule in the design's sections on steering documents, package documents and decision records is stated in exactly one skill or shared document, and no text in the repository contradicts it.
- `validate-documents` exists in the baseline with its six checks, and each check has a fixture that fails and one that passes.
- The devkit itself passes it: no `AGENTS.md`, no root `CLAUDE.md`, no `docs/adr/`, the ten rule files, and the records the design keeps, under their new names.
- No file mentions `docs/adr`, a record by number or `AGENTS.md`, outside changelogs and provenance records.
- `repo:init` and `repo:add-package` write the new file set, and the example tree in `README.md` matches it.
- Every plugin whose text changed has a version bump and a changelog entry.

## Proof owed in the pull request

- The full check passes.
- The output of one headless run in a scratch repository built from what `repo:init` now writes, showing that the intent is in context at launch and that a path-scoped rule file loads after a matching read.
- What you found for the three unverified points listed in the roadmap under "steering-documents and principles-and-why".

## Facts that save a search

- 34 references to a record by number sit in 19 files.
- The structure marker is read in `plugins/repo/hooks/session-start.sh`, in `repo:add-package`, in `docs/conventions/prerequisites.md` and in `scripts/validate-prerequisites.py`.
- `shared/ADR-FORMAT.md` is symlinked from `plugins/conventions/skills/adr/` and `plugins/discover/skills/domain-model/`.
- The package document check is `check_package_docs` in `devenv/validate-structure.py`, and its fixtures are in `devenv/tests/validate-structure.sh`.
- The headless method is `claude -p` in a scratch repository outside this checkout, with the real purpose stated in the prompt.

## When the work lands

Do not remove the design or the roadmap; the next pull request needs both.
Change this piece's row in the roadmap's status table to "Landed".
Remove this file and its `docs/TODO.md` entry in the last commit.
