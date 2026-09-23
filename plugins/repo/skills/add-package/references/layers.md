# Layer lint

The core library of a context holds `domain/` and `application/` as modules.
The lint below fails the commit when domain imports another layer, application imports anything but domain, or either imports a contract, an adapter or an app.
The validator in the baseline module enforces the rules between packages; this enforces the rules inside one.

## Python: import-linter

In the core library's `pyproject.toml`:

```toml
[tool.importlinter]
root_package = "{ctx}"

[[tool.importlinter.contracts]]
name = "Layers point inward"
type = "layers"
layers = ["{ctx}.application", "{ctx}.domain"]

[[tool.importlinter.contracts]]
name = "The core never imports the boundary"
type = "forbidden"
source_modules = ["{ctx}.domain", "{ctx}.application"]
forbidden_modules = [{generated client packages and adapter packages of this context, as import names}]
```

Add `import-linter` to the root workspace's dev dependency group, and in the package's `devenv.nix`:

```nix
git-hooks.hooks."{ctx}-layers" = {
  enable = true;
  name = "{ctx} layers";
  entry = "uv run lint-imports --config libs/{ctx}/pyproject.toml";
  files = "^libs/{ctx}/";
  pass_filenames = false;
};
```

## TypeScript: dependency-cruiser

`libs/{ctx}/.dependency-cruiser.cjs`:

```js
module.exports = {
  forbidden: [
    {
      name: "domain-imports-nothing",
      from: { path: "^src/domain" },
      to: { path: "^src/(application|adapter)", pathNot: "^src/domain" },
    },
    {
      name: "application-imports-domain-only",
      from: { path: "^src/application" },
      to: { path: "^src/", pathNot: "^src/(domain|application)" },
    },
    {
      name: "core-never-imports-the-boundary",
      from: { path: "^src/(domain|application)" },
      to: { path: "node_modules/(@{scope}/{ctx}-|@{scope}/{contract})" },
    },
  ],
  options: { tsPreCompilationDeps: true, tsConfig: { fileName: "tsconfig.json" } },
};
```

Add `dependency-cruiser` to the root workspace's dev dependencies and a hook in the package's `devenv.nix` running `pnpm --filter {ctx} exec depcruise src`, scoped with `files = "^libs/{ctx}/"`.

## Go: depguard through golangci-lint

In the core library's `.golangci.yml`, a `depguard` rule per layer: the `domain` package list denies imports of `.../application`, adapters and generated clients; the `application` list denies adapters and generated clients.
The `golangci-lint` hook from the stack table runs it.

## Rust

No module-level lint exists.
Keep the direction by review, and when it must be enforced, split the domain into `libs/{ctx}-domain` so the compiler enforces it through crate dependencies.
That is the one case where a layer becomes a package without a dependency-leak reason.
