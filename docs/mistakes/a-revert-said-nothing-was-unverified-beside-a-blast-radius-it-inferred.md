# A revert said nothing was unverified beside a blast radius it inferred

- **Date**: 2026-11-18
- **Caught in**: [revert(build): take out the OpenTofu route without a go-ahead, merged by mistake](https://github.com/lyngon/devkit/pull/202)

The body of pull request 202, which took out pull request 198 after it merged by mistake, said "Not verified: None", while its blast radius marked a claim as inferred from the code.
It also left out what the reverted tool does with state that 198's tool wrote, which no run had covered.
The review of the work trace caught it, and a comment on 202 gives the measured behavior: the revert fails safe, but a log line of the kinds only 198's tool writes stops main's tool with a traceback.
