# A scores comment named a Claude Code version read before the runs

- **Date**: 2026-11-18
- **Caught in**: [feat(build): apply an unprotected OpenTofu root without a go-ahead](https://github.com/lyngon/devkit/pull/203)

The agent wrote Claude Code 2.1.322 into the eval scores comment of pull request 203, a version it had read earlier that day, while `compare-evals` had run the `claude` on the PATH, which by then was 2.1.325.
`compare-evals` records no version, so nothing in its output showed the error, and the scores comment of pull request 198 likely names the same wrong version for its last rescores.
The review of the work trace caught it, and the comment now names the version that `claude --version` printed right after the runs.
