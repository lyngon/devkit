# Principles and why

Seed prompt for a fresh Claude Code session in the devkit repository.

This is the second of two pull requests that implement one approved design.
The first, `steering-documents`, must have landed.
Implement in this session: no new design and no plan file, which the owner chose for this program.

## What to read first

- [The design](../plans/2026-10-07-principles-and-steering-documents.md), sections "The `principles` plugin" and "The `why` skill", with their parts of Data flow, Error handling and Testing.
- [The roadmap](../plans/2026-10-07-philosophy-overhaul-roadmap.md), sections "The philosophy", "Settled for every piece" and "steering-documents and principles-and-why".

## Branch

`feat/principles`, from the default branch.

## The upstream

Clone `https://github.com/cursor/plugins` and check out commit `9f451cf875ad1239912762f67741e8e5ba6ac0f1`.
The principles are the 24 directories `pstack/skills/principle-*`, and `why` is `pstack/skills/why`.
Vendor both through `/devkit:add-skill`.
Read every file you vendor in full before you patch it; nobody has read the reference files of `why`.

## What must hold when you are done

- `principles:index` lists 31 principles, 24 from pstack and 7 from Lyngon, each with a file under 100 lines, and the validator fails when the index and the files disagree.
- Every local patch the design names is applied and listed in the provenance record, and no other change to upstream text is unlisted.
- The seven Lyngon principles are written in upstream's shape (statement, why, pattern, test), from the statements in the design.
- `discover:why` answers from the decision records, git, pull request bodies and issues, in one pass when no other source exists, and keeps upstream's split between found, inferred and unknown.
- A session in a Lyngon repository is told about `principles:index` by the session hook.

## Proof owed in the pull request

- The full check passes.
- One headless run that asks for a small change taking judgment, where the transcript shows the index and at least one principle file being read.
- The output of `discover:why` on "why is the `all` bundle the install unit?".

## When the work lands

Remove the design file `docs/plans/2026-10-07-principles-and-steering-documents.md`.
Remove the section "steering-documents and principles-and-why" from the roadmap and both rows from its status table; the roadmap itself stays.
Remove this file and its `docs/TODO.md` entry in the last commit.
