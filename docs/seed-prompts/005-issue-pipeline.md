# Issue pipeline

Seed prompt for a fresh Claude Code session in the devkit repository.

Start by invoking the `discover:approach` skill with this brief as the request.
The work is architectural.
`agent-identity` and `workflow` must have landed.

## The request

Move tasks from `docs/TODO.md` and seed prompts to GitHub Issues: a tool for filing, a triage that turns a raw report into an issue an agent can work from, and a command with which the operator picks the next one.

## What to read first

[The roadmap](../plans/2026-10-07-philosophy-overhaul-roadmap.md), sections "Settled for every piece" and "issue-pipeline".
Most of this piece's design was settled in the interview.
Do not reopen what is settled or rejected there; interview the owner on what the roadmap leaves out, such as the exact fields of the classifier's verdict, the priority guidelines, and where the filing tool lives.

## The constraint that shapes it

`lyngon/devkit` is public, so the text of an issue is untrusted input that reaches an agent holding credentials.
The design must show, for each step that reads issue text, what that step is able to do.

## Proof owed

An issue filed by an outsider account with an instruction hidden in its body ends up labelled and commented from a template, and nothing else happens.

## Branch

`feat/issue-pipeline`.

## When the work lands

File every remaining `docs/TODO.md` entry as an issue or drop it, then remove `docs/TODO.md` and `docs/seed-prompts/`.
Remove the section "issue-pipeline" from the roadmap and its row from the status table.
Remove this file and its `docs/TODO.md` entry in the last commit.
