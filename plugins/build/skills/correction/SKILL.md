---
name: correction
description: "Record a mistake an agent made in this repository, and make a mistake that repeats impossible. A first occurrence becomes a file in the mistake ledger under docs/mistakes/. A repeat is fixed at the highest level that works: architecture first, then types, then a lint whose error names the fix, then a test, and prose last, with each check proven to fail on a real past mistake. Use each time the operator corrects you, a review finding is accepted or a change is reverted, and for 'correct' or 'find the mistakes agents keep repeating'. Not for a check or a test that failed."
argument-hint: "[the mistake, or nothing to look for the ones that repeat]"
---

# Correction

The operator keeps correcting agents in this repository for the same mistakes.
Change the repository so the next agent can't make them.

Assume every contributor is an agent that sees only the files it opened, copies the nearest example, and takes the shortest path that compiles.
Design the repository so a change that looks right from one file is right for the whole repository.

## Find the mistake classes

A correction from the operator, a review finding that was accepted and a change that was reverted each hand you a mistake.
A check or a test that failed hands you none, because that mistake already fails.
Asked for the mistakes agents keep repeating, read recent commits, reverts, review comments, the rule files under `.claude/rules/`, and comments that explain workarounds.

Either way, read every file of the mistake ledger, `docs/mistakes/`, before you write anything.
Group the mistakes into classes.
A class counts once it has happened twice, and the ledger holds the ones that have happened once.

## Fix each class at the highest level that works

1. **Eliminate it with architecture.** Give each piece of state one owner and each task one supported way. Hide internals so the wrong import fails. Replace hand-synced lists with one source of truth. Delete old ways and dead code an agent would copy.
2. **Enforce it with types so the bad state can't be written.** If bad code still compiles, add a lint or CI check whose error names the file, type, or function to use instead. If the pattern is already common, fail only when a change adds more.
3. **Test the behavior.** Fix or delete any test that would still pass if every function it calls returned nothing.
4. **Write a principle last, only for judgment calls.** Nothing fails when an agent skips it. A class that no tool can decide becomes a rule file under `.claude/rules/`, named after the principle. The owner approves the principles of the repository, so name the file in the pull request.

## Fix and prove

Then fix the most frequent classes now, one commit each.
Prove each new check fails on a real past mistake.
Run the same command locally and in CI.
Exceptions go on the offending line with a reason, an expiry date, and the owner's approval.

## Keep the mistake ledger

Last, keep the ledger: one file in `docs/mistakes/` for each mistake that has happened once.
When a mistake is not in the ledger, fix it and write its file, named after the mistake in kebab-case:

```md
# <The mistake, as a sentence>

- **Date**: <the day it was caught, as YYYY-MM-DD>
- **Caught in**: [<pull request title>](<pull request link>)

<What happened, in two or three sentences.>
```

Leave the line **Caught in** out while the pull request does not exist, and add it once the pull request is open.
`validate-documents` fails a file of another shape.

If the mistake was already in the ledger, that's a repeat, so fix it at the highest level in the same change and delete its file.

Every time you use this skill, run its `scripts/prune-mistakes.py` from the root of the repository, and commit what it deleted.
It deletes the files older than the limit the repository sets with `lyngon.mistakes.maxAgeDays`, because a mistake that stayed alone that long is no class.

**Reply:** each class with its evidence. For a first occurrence, the ledger file you wrote. For a repeat, the level you picked, why a higher level didn't work, and the check failing on the past mistake.
