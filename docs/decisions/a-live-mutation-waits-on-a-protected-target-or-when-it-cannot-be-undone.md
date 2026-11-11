# A live mutation waits on a protected target or when it cannot be undone

On a protected target every live mutation waits for a go-ahead, a reversible apply included, because no review follows it before it takes effect.
On an unprotected target only a live mutation that cannot be undone, or one the standing instructions always ask about, waits.
A target is protected unless a rule file of its repository names it unprotected, so a new target that nobody declared waits instead of running ungated.
A live mutation that needs no go-ahead owes no proposal and no action record, only the proof any work owes.

## Considered options

- Waiting only before an irreversible live mutation, everywhere, lets a reversible apply change production with nothing shown first.
- Waiting before every live mutation, everywhere, makes each Sandbox apply and each Experiment stop for the owner.
- Declaring the protected targets instead leaves a production-like target ungated until someone remembers to declare it.
- A proposal and an action record for every live mutation would put a record of each Sandbox apply on every pull request, where nobody reads it.

Enforced by: judgment
