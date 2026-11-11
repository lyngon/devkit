---
plugins: ["../../.."]
max_turns: 80
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Write]
---
/repo:init fresh

This directory is empty: no files, no commits and no remote. No shell is available in this session, so take that as the inventory, and leave out the verification and the commit.
I cannot answer a question in this session. Below is my answer to every question of the interview, and I confirm in advance the shared understanding and the file set that follow from these answers. Ask nothing and write the files.

- Failure in a year: a harbour pilot trusts a prediction of the water height that is off by more than 10 centimetres.
- Problem: pilots bring ships into harbours on tide tables printed once a year. Tidewatch predicts the height of the water in each harbour, minute by minute, from its tidal constituents.
- Non-goals: weather, waves and currents.
- Lifetime: years.
- Repository audience: the Tidewatch team.
- Artifact audience: harbour pilots and the scheduling system of the port authority.
- Technologies: Python with uv.
- Structure: no. The repository holds one Python project at its root, with its code under `src/tidewatch` and its tests under `tests/`. The code and its `pyproject.toml` come in a later change, so write neither.
- Delivery: none yet. The deployment comes in a later change.
- Git host and CI: GitHub with GitHub Actions.
- Constraints, secrets and services: none.
- Test strategy: unit tests with `uv run pytest`, which `devenv test` runs.
- Terms, stack choices with lock-in, decision records and rule files: none.
