# A merge as the go-ahead

A workflow that runs a live mutation when a pull request merges, such as CI that applies on merge, holds the rules of a session with the pull request in place of the conversation.
The protection of the default branch decides who can give the go-ahead, since it decides who can merge.

## What must hold

- The pull request shows the proposal derived at its head: the rendering, the command that runs, every check with its result, and the digest. The workflow posts it as a comment and posts it again after every push.
- The merge is the go-ahead for the proposal shown at the head that merged, and for nothing else. The workflow runs that proposal's frozen inputs, verified by their digest, such as the OpenTofu saved plan of the pull request's run, and never derives them again at merge time.
- The workflow refuses a proposal derived at another head, or at a head whose tree differs from the tree that merged, as when the branch was behind the default branch. Requiring a branch to be up to date before it merges keeps the two trees equal.
- Right before the run, a drift check derives and renders again from live state, and the run goes ahead only when the rendering equals the one the pull request showed.
- A refused, drifted or failed run is never retried on its own. A new proposal needs a new go-ahead.
- After the run, the workflow runs every check again and posts the action record as a comment on the merged pull request. Each check has a failing run in the record, as in a session.
- No secret enters a comment. The frozen inputs stay in the workflow's own storage, named by their digest.

## Proof owed

For a workflow built to these rules: a run that refused a proposal derived at an older head, and a merged pull request whose action record shows the run and every check.
