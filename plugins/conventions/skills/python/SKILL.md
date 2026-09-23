---
name: python
description: Lyngon Python conventions. Background knowledge, loaded automatically while working on Python files, stubs and notebooks.
user-invocable: false
paths:
  - "**/*.py"
  - "**/*.pyi"
  - "**/*.ipynb"
---

# Python conventions

## Project

- uv manages everything: `uv add`, `uv run`, `uv sync`. Never `pip`, never `pip install`, never a hand-made virtual environment.
- A package's `pyproject.toml` declares constraints (`httpx>=0.27`); the workspace lockfile pins.
- Development dependencies go in `[dependency-groups]`, not in `[project.optional-dependencies]`.
- `requires-python` is set once, at the root, to the newest stable release the toolchain provides.
- Packages use the `src/` layout: `src/<import_name>/`. The import name is the distribution name with underscores.
- An app exposes its entry point in `[project.scripts]` and keeps `main` in `__main__.py`; nothing else lives in an app.

## Code

- Type hints on every function signature and every module-level name. The code must pass a strict type checker; `Any` does not cross a package boundary.
- Domain values are `@dataclasses.dataclass(frozen=True, slots=True)` or plain classes. pydantic and other validation libraries appear only in adapters and entrypoints, where data enters.
- Exceptions are typed per domain and raised at the boundary where the rule is broken. Never a bare `except`, never `except Exception: pass`.
- Logging through `logging.getLogger(__name__)` at module level. No `print` in a library.
- `async` only in adapters and entrypoints. Domain and application code is synchronous.
- Pathlib over `os.path`; `subprocess.run` with an argument list over shell strings.
- A public module, class or function has a docstring that states its contract or its reason: what it guarantees, what it raises, why it exists. Never the name restated as a sentence.

## Imports

- Import modules, never names: `import pathlib`, then `pathlib.Path` at every use, so every name shows where it comes from.
- `from a.b import c` only when `c` is a module, for a long package path. No `from x import *`.
- Absolute imports only, also within a package.
- Fixed aliases, and no others: `import typing as t`, `import collections.abc as ct`, `import datetime as dt`, and the conventional third-party aliases (`numpy as np`, `pandas as pd`, `polars as pl`).
- Abstract collection types come from `ct`, not `t`: `ct.Iterable`, `ct.Callable`, `ct.Mapping`.
- A package's `__init__.py` may re-export its public names (`from orders._order import Order`); that is the one place names are imported.

## Tests

- pytest, in `tests/` next to `src/`, named after the behaviour: `test_order_cannot_ship_twice`.
- Fixtures over setup methods; parametrize over copy-paste.
- Tests import the package the way a consumer does.

## Stubs and notebooks

- `.pyi` stubs only for third-party packages that ship no types, under `typings/` at the package root.
- Notebooks are exploration. They are never imported, and their outputs are stripped before commit.

## With the Lyngon baseline

- Checked by the `ruff-format` and `ruff` hooks against the root `ruff.toml`: every stable ruff rule, minus a short ignore list with a reason on each entry. It also enforces the import rules above, except that a `from` import names a module.
- The root `ruff.toml` is the only ruff configuration. A `[tool.ruff]` table in a package's `pyproject.toml` silently replaces it.
- Silence a single finding with `# noqa: CODE  # reason`. Extend the ignore list only with a reason on the entry.

## With the Lyngon structure

- One uv workspace at the repository root with explicit members; `uv.lock` at the root pins.
- A core library holds `domain/` and `application/` under `src/<ctx>/`, with import-linter enforcing the direction; `/repo:add-package` writes the contract.
- Domain and application never import a generated client, an adapter or a framework.
