# A proposal runs only in the conversation that showed it

A go-ahead answers what the owner saw, so a proposal shown in one conversation never runs in another: a new session, a fork or a handover derives it again and asks again.
A compaction and a resume keep the conversation, and with it the proposal.
Right before the run, a drift check derives the rendering again from live state, and the run goes ahead only when it equals the rendering the owner approved, because OpenTofu refuses a saved plan whose state changed but not one whose live resources drifted.

## Considered options

- Ending a proposal with the process that showed it makes a resume derive again, while a laptop that sleeps for three hours keeps its process. The drift check covers both.
- A fixed lifetime needs a number that no live system gives.

Enforced by: judgment
