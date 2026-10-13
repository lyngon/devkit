# A switch from subprocess.run to Popen dropped the kill on an interrupt

- **Date**: 2026-10-13
- **Caught in**: [fix(scripts): a comparison says when a run lacked a tool](https://github.com/lyngon/devkit/pull/51)

To pass the output of `claude plugin eval` on line by line, the agent replaced `subprocess.run` in `scripts/compare-evals.py` with a `subprocess.Popen` block and a loop of its own.
`subprocess.run` kills its child on any exception and a bare `Popen` block does not, so an interrupted comparison removed its scratch directory while the paid run went on.
The reviewer of the branch measured it with a stub, and the fixture test now interrupts the program and checks that the run is gone.
