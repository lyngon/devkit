# An issue was filed from a stale checkout of another repository

- **Date**: 2026-11-01

While designing agent identity, the agent read `apply` in the owner's local clone of `d00astro/nixos-configs`, which was checked out on an older branch, and filed issue 19 against its sops recipient logic.
The default branch had already fixed that logic, and the owner had closed the issue.
The owner pointed it out, and reading `apply` at `master` through `gh api` showed the fix.
