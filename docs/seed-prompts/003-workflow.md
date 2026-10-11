# Workflow

Seed prompt for a fresh Claude Code session in the devkit repository.

Start by invoking the `discover:approach` skill with this brief as the request.
The work is architectural.
`steering-documents` and `principles-and-why` must have landed.

## The request

Replace the devkit's gated workflow (two review gates, plans, owner gates, the execution ledger, and nine skills vendored from superpowers) with a thin flow built on skills vendored from pstack: a prompt or an issue in, proof and a pull request out.
Process is spent on proof, not on permission.

## What to read first

[The roadmap](../plans/2026-10-07-philosophy-overhaul-roadmap.md), in full.
Its section "workflow" lists what the owner settled and what is open.
Do not reopen what is settled or what is listed as rejected; interview the owner only on the open points and on what the roadmap does not cover.

## The upstream

Clone `https://github.com/cursor/plugins` and check out commit `9f451cf875ad1239912762f67741e8e5ba6ac0f1`, or a newer commit if the owner agrees to a bump.
Read every skill and playbook the roadmap lists as taken before you design around it.

## Shape of the work

The design will probably split into several changes, since it removes four plugins' worth of text and vendors fourteen skills and six playbooks.
Propose the split and its order in the design.
The owner reviews the design file; the implementation then happens without a plan file, and the owner reviews each pull request.

## Branch

`feat/workflow` for the design, and one branch per change after that.

## When the work lands

Remove the section "workflow" from the roadmap and its row from the status table.
Remove the `docs/TODO.md` items the roadmap lists as moot.
Remove this file and its `docs/TODO.md` entry in the last commit.
