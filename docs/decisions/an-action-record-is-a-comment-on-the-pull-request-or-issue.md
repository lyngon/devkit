# An action record is a comment on the pull request or issue

The action record of a live mutation is a comment on the pull request whose branch the mutation ran from, without one on the issue of its task, and without either on an issue opened for the mutation.
It holds the rendering the owner read and the outputs, never a frozen input that may hold a secret, such as an OpenTofu saved plan, which holds sensitive values in plain text.
The record of a run without a go-ahead whose branch has no pull request yet waits for one, and `build:pull-request` posts it there, since it is proof of the work, as the work trace is, and a worktree that dies with it loses no go-ahead.

## Considered options

- The record of a run without a go-ahead goes on the issue of the task, or on an issue opened for it, while the branch has no pull request. That puts a comment there for each Sandbox apply of a branch, most of them steps on the way, and none where a reviewer reads the change.
- A committed file per live mutation, such as under `docs/actions/`, keeps history in the tree, which the principle `the-tree-is-current` forbids, and grows with every mutation.
- The gitignored workspace the mutation ran from dies with the session or the worktree, which is where the evidence of the applies in [feat: bootstrap the state bucket and LyngonTofu](<https://github.com/lyngon/lyngon.com/pull/3>) was lost.

Enforced by: `plugins/build/tests/live-mutation.sh` for a record that holds no frozen input and for one that waits, which `pending` lists, and judgment
