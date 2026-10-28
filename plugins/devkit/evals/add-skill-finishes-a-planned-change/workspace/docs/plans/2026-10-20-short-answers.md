# Short answers: design

The design of short answers, settled with the owner on 2026-10-20.
It is transient: the last of its changes removes it.

## Design

Agents answer a one-line question with a page.
The plugin `writing` gains a skill that keeps a reply as short as its question allows, vendored from acme/brevity.
A second change makes the other skills of `writing` point at it.

## Changes and their order

One branch and one pull request per change, in this order.

| Change | Branch | Does | Proof owed |
| --- | --- | --- | --- |
| `001-brevity` | `feat/brevity` | `writing:brevity`, vendored from `skills/concise-replies` of acme/brevity. It is renamed, because a skill's name is a noun that reads after its plugin's. | One eval case for its trigger. |
| `002-pointers` | `feat/brevity-pointers` | `writing:plain` names `writing:brevity`. This file is removed. | The validators. |
