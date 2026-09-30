# Run the build scripts in a worktree-isolated session

Seed prompt for a fresh Claude Code session in the devkit repository.

This is a bounded change: no design file and no plan file.
Start by reproducing both facts below end to end, since the fix depends on which of them still holds.
Work on the branch `fix/script-invocation-in-worktrees`.

## The problem

The `build` skills tell the agent to run their scripts through `bash`, for example `bash <this skill's directory>/../delegate/scripts/workspace PLAN_FILE` in `plugins/build/skills/finish/SKILL.md`, and `plugins/build/skills/delegate/references/owner-gates.md` says to run every script it names "with `bash`".
The scripts do the same with each other (`task-brief`, `review-package`, `execution-status`, `task-start`, `task-done`), each with the comment that some plugin installers strip Unix exec bits when unpacking.

In a Claude Code session isolated in a worktree, the harness refuses `bash <script>` for a script that runs git: "this command is too complex to verify that it stays inside the worktree".
It also refuses a chained command that names git (`cd dir && git ...`, `git a; git b`), and python fed text that names git.
Running the same script as an executable (`plugins/build/tests/scripts.sh`, `<dir>/review-package ...`) works.
In the owner gates work (pull request #7, 2026-09-30) every implementer and reviewer hit this, wrote wrapper scripts or split commands, and one brief had to be amended because its test step said `bash plugins/build/tests/scripts.sh`.
The skills' own instruction is the form the harness refuses.

## Decisions to settle in the change

1. Whether plugin installation still strips exec bits: install the marketplace into a scratch directory the way a consumer does (`claude plugin install build@lyngon --scope project` from a clean checkout) and check the modes of `plugins/build/skills/*/scripts/*`. If the bits survive, the `bash` form has no reason left.
2. The form the skills should use: the executable path, with `bash` only as a fallback when it fails with "permission denied"; or keep `bash` and state the worktree limit.
3. Whether the scripts' calls to each other change too (they run inside the script, so the harness never sees them; likely no change).
4. Whether a line belongs in the implementer and reviewer templates: one plain git command per shell call, scripts run as executables.

Each change to a vendored `build` skill gets its `UPSTREAM.md` local patch, and the plugin its version bump and `CHANGELOG.md` entry.

Remove this file and its `docs/TODO.md` entry in the last commit.
