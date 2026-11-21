# A name claimed a copy before the copy was made

- **Date**: 2026-11-21
- **Caught in**: [fix(scripts): keep the trace of each compare-evals run below 1.00](https://github.com/lyngon/devkit/pull/240)

To keep the trace of each failed run, the agent gave `scripts/compare-evals.py` a class `KeptTrace` with a field `kept`, which `parse_result` filled long before `keep_traces` made the copy.
Three docstrings then had to say that a trace "gets a place" and "is not copied here".
`build:comment-auditor` deleted them and flagged the names, and the class is now `TraceToKeep` with a field `destination`.
