# GitHub repository setup

Seed prompt for a fresh Claude Code session in the devkit repository.

Start by invoking the `discover:approach` skill with this brief as the request, and let it classify the work.
`steering-documents`, `agent-identity` and `issue-pipeline` must have landed.

## The request

`repo:init` sets up a repository's files and nothing on GitHub.
Add the GitHub side: the ruleset, CODEOWNERS for the steering documents, the triage labels, the issue forms and the merge settings.

## What to read first

[The roadmap](../plans/2026-10-07-philosophy-overhaul-roadmap.md), sections "Settled for every piece" and "github-repository-setup".
Do not reopen what is settled or rejected there.

## What to test before designing

Whether a ruleset with zero required approvals and required code-owner review lets a pull request that touches no owned path merge without approval, and blocks one that does.
The roadmap marks this as inferred.
Test it on a scratch repository and bring the result into the design, since review level B (issue 13) depends on it.

## Proof owed

A fresh repository set up by `repo:init` and the emitted script refuses a merge commit, refuses a pull request title that is not in Conventional Commits form, and blocks an agent's pull request that changes `INTENT.md` until the owner approves it.

## Branch

`feat/github-repository-setup`.

## When the work lands

Remove the section "github-repository-setup" from the roadmap and its row from the status table.
Remove this file and its `docs/TODO.md` entry in the last commit.
