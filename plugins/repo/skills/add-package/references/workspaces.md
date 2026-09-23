# Workspace roots

One workspace per language at the repository root, members listed explicitly, one lockfile.
Languages are enabled in the root `devenv.nix`, never in a package.

## Python: uv

Root `pyproject.toml`:

```toml
[project]
name = "{repository}"
version = "0.0.0"
requires-python = ">=3.13"

[tool.uv.workspace]
members = [
  "apps/orders-api",
  "libs/orders",
  "libs/orders-postgres",
]

[tool.uv.sources]
orders = { workspace = true }
orders-postgres = { workspace = true }

[dependency-groups]
dev = ["pytest", "import-linter"]
```

Root `devenv.nix`: `languages.python = { enable = true; uv.enable = true; uv.sync.enable = true; };`.

Lint rules live in the root `ruff.toml` (the `init` skill's `devenv.md` reference).
A package's `pyproject.toml` never gets a `[tool.ruff]` table; it would replace the root configuration for that package.

## TypeScript: pnpm

Root `pnpm-workspace.yaml`:

```yaml
packages:
  - apps/orders-web
  - libs/orders
```

Internal dependencies use the `workspace:*` protocol in `package.json`.
Root `devenv.nix`: `languages.javascript = { enable = true; pnpm.enable = true; pnpm.install.enable = true; }; languages.typescript.enable = true;`.

## Rust: Cargo

Root `Cargo.toml`:

```toml
[workspace]
resolver = "3"
members = ["apps/orders-cli", "libs/orders"]

[workspace.dependencies]
orders = { path = "libs/orders" }
```

Packages depend on internal crates with `orders = { workspace = true }`.
Root `devenv.nix`: `languages.rust.enable = true;`.

## Go

Root `go.work`:

```text
go 1.25

use (
  ./apps/orders-cli
  ./libs/orders
)
```

Root `devenv.nix`: `languages.go.enable = true;`.

## Terraform

No workspace.
`infra/environments/<env>/` roots reference `infra/modules/<name>/` by relative `source`.
Root `devenv.nix`: `languages.terraform.enable = true;`.
