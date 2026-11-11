---
plugins: ["../../.."]
max_turns: 80
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---
/repo:init adopt

The working directory is the repository: one commit on `main`, no remote, and the tracked files `README.md`, `INTENT.md`, `.claude/CLAUDE.md`, `pyproject.toml` and `src/tidewatch/__init__.py`. No shell is available in this session, so take that as the inventory, and leave out the branch, the verification and the commit.
I cannot answer a question in this session. Below is my answer to every question of the interview, and I confirm in advance the shared understanding, the sorting of every existing file and the file set that follow from these answers. Ask nothing and write the files.

- Failure in a year: a pilot trusts a prediction that is off by more than 10 centimetres.
- Problem: pilots bring ships into harbours whose water rises and falls with the tide, and need its height for every minute of an arrival.
- Non-goals: weather, waves and currents.
- Lifetime: years.
- Repository audience: the Tidewatch team.
- Artifact audience: harbour pilots and the scheduling system of the port authority.
- Technologies: Python, with uv.
- Structure: no. The repository keeps its `src/` layout.
- Delivery: none yet.
- Git host and CI: GitHub with GitHub Actions.
- Constraints, secrets and services: none.
- Test strategy: unit tests with `uv run pytest`, which `devenv test` runs.
- Terms, stack choices with lock-in and decision records: none. Leave the commented linters commented.
- The existing documents: keep `INTENT.md` as it is. I want the principle in `.claude/CLAUDE.md` about heights of the water kept as it is written: nothing fails when an agent stores a height as a float.
