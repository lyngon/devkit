# A test stub computed what the real tool prints

- **Date**: 2026-10-13
- **Caught in**: [fix(scripts): a comparison says when a run lacked a tool](https://github.com/lyngon/devkit/pull/51)

The stub of `claude` in `scripts/tests/compare-evals.sh` parsed `--allow-tools` and worked out which tools a case lacked, the way the harness does.
Two checks then passed or failed on the stub's own arithmetic and said nothing about `compare-evals`, and the stub left out lines that the real harness prints.
The reviewer of the branch found it, and the stub now prints a canned progress made of lines copied from a real run.
