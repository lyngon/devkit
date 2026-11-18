# An action record is a comment on the pull request or issue

The action record of a live mutation is a comment on the pull request whose branch the mutation ran from, without one on the issue of its task, and without either on an issue opened for the mutation.
It holds the rendering the owner read and the outputs, never a frozen input that may hold a secret, such as an OpenTofu saved plan, which holds sensitive values in plain text.

## Considered options

- A committed file per live mutation, such as under `docs/actions/`, keeps history in the tree, which the principle `the-tree-is-current` forbids, and grows with every mutation.
- The gitignored workspace the mutation ran from dies with the session or the worktree, which is where the evidence of the applies in [feat: bootstrap the state bucket and LyngonTofu](<https://github.com/lyngon/lyngon.com/pull/3>) was lost.

Enforced by: judgment
