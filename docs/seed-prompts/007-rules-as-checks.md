# Rules as checks

Seed prompt for a fresh Claude Code session in the devkit repository.

Start the session with `/discover:approach`, with this file as its argument: only the operator can start that skill.
The first session designs the sorting and the order; after that each check is a bounded change of its own.

## The request

Every rule a tool can decide gets a check, and the prose that stated it is deleted.
Sort the text of the `conventions` skills and of `shared/STRUCTURE.md` into principles, which stay as prose, and rules, which move into a linter, a hook or a validator.

## What to read first

[The roadmap](../plans/2026-10-07-philosophy-overhaul-roadmap.md), sections "Settled for every piece" and "rules-as-checks".
Issue 14 on `lyngon/devkit`, which covers the structure and names the five checks it still lacks.

## What the first design must produce

A table of every rule found, with the tool that will check it, and the order in which the checks land.
Order them by how often an agent would break the rule with nothing failing, not by how easy the check is.

## Proof owed for each check

The check fails on a fixture that breaks the rule, its message names the fix, and the prose it replaces is gone in the same change.

## Branch

`feat/rules-as-checks` for the design, and one branch per check after that.

## When the work lands

This piece has no single landing.
When the table is empty, remove the section "rules-as-checks" from the roadmap, and the roadmap file itself if no other section is left.
Remove this file and its `docs/TODO.md` entry in the same commit.
