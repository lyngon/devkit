# The Lyngon workflow is a prerequisite, and `core` leaves it out

ADR 0016 made commits, pushes and pull requests the user's standing instructions, carried by `conventions:engineering` and by a session hook that tells every session "This is a Lyngon repository".
`conventions` declared only `documents`, so it sat in `core`, the bundle meant to work in any repository with the Lyngon documents, and enabling `core` for a user would have carried those instructions into every repository they open.
We add a fourth prerequisite, `workflow`: the owner has adopted the Lyngon workflow for the repository, which is what enabling `conventions` does.
`conventions` and `repo` declare it, so `core`, which holds exactly the plugins declaring at most `documents`, no longer includes `conventions`.

## Considered options

- `build` declaring `workflow` too, since `build:finish` pushes and opens the pull request: it would have left `core` without planning and execution, and restated the authorization in a second place. Instead `build:finish` asks once before the push unless the user's standing instructions cover it, and a `With the Lyngon workflow` section says that `conventions:engineering`'s do.
- A check of the repository's settings in the hook and the skills, so that a user-scope install stays inert elsewhere: rejected, since `conventions` is enabled per repository and a conditional in every hook and skill is hard to follow.

## Consequences

- Declarations are `documents`, `workflow`, `baseline`, `structure`, in that order, and the four are independent. `conventions` declares `documents, workflow`; `repo` and `all` declare all four.
- The validator treats `conventions:engineering` and "This is a Lyngon repository" as the workflow's terms. An agent recognises the workflow by its session context, which says "This is a Lyngon repository" when `conventions` is enabled; no hook or skill reads the settings to tell.
- `core` may be enabled at user scope: without `conventions` it never pushes without asking. Its executors still commit each task on a feature branch, and its skills still write the Lyngon documents where they run.
- `repo:init` adopts the workflow in every scope: the settings it writes enable `conventions` next to `core` or `all`.
