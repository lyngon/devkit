# Agent identity

Seed prompt for a fresh Claude Code session in the devkit repository.

Start by invoking the `discover:approach` skill with this brief as the request, and let it classify the work.

## The request

Give agents their own GitHub identity, so that the forge can tell an agent's issue, commit and pull request from the owner's, and so that the owner can approve an agent's pull request.
Today agents push with the owner's token.

## What to read first

[The roadmap](../plans/2026-10-07-philosophy-overhaul-roadmap.md), sections "Settled for every piece" and "agent-identity".
Do not reopen what is settled or rejected there; interview the owner on the open points.

## What only the owner can do

Creating the GitHub App needs one confirmation in a browser, storing its private key is done in the owner's Nix configuration, and upgrading the organization to the Team plan is a purchase.
Prepare each of these as an exact step for the owner and stop there.

## Proof owed

A session in a repository that enables the baseline opens a pull request whose author is the App, while a commit made from the owner's own shell in the same checkout is the owner's.

## Branch

`feat/agent-identity`.

## When the work lands

Remove the section "agent-identity" from the roadmap and its row from the status table.
Remove this file and its `docs/TODO.md` entry in the last commit.
