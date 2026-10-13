# A problem found on the way was left as a remark

- **Date**: 2026-10-13
- **Caught in**: [docs(mistakes): a problem found on the way was left as a remark](https://github.com/lyngon/devkit/pull/39)

While fixing issue 23, the agent found a `commit-msg` shim in the hooks directory that the worktrees share, which still named the main checkout's hook configuration by its absolute path.
It judged the shim harmless, because no hook ran at that stage, and mentioned it in the hand-over of pull request 37 with neither an issue nor a fix.
The owner asked why no issue was filed, and the look that followed showed that the shim fails every commit once its configuration is gone, which pull request 38 fixed.
