# A check read the text of an argument and the program sent another word

- **Date**: 2026-10-14
- **Caught in**: [fix(scripts): compare-evals checks the number of runs that it sends](https://github.com/lyngon/devkit/pull/61)

To keep a negative `--runs` from the harness, the agent made `scripts/compare-evals.py` refuse a value whose text starts with a dash, and then sent `str(int(text))`.
`int` drops white space, so `--runs=' -1'` passed the check and reached the harness as the word `-1`.
The agent found it after pull request 56 had merged, when the owner asked what was left, and the type of the option now returns the digits that the check read, which are what the program sends.
