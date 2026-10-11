# Package files

Templates for the files of an app or library.
Replace every `{placeholder}` and leave no template comments behind.

## README.md

```md
# {name}

{One paragraph: what it is and what it does for the context.}
{For an app: the deployable kind (image, web bundle, binary, function package) and the runtime units it backs.}
{When the package has an `INTENT.md`: a link to it.}

## Run

{How to run or use it from the devenv shell, one command per line in a code block.}

## Test

{The test command.}
```

## INTENT.md

Written only on a yes to the question in step 5 of the skill, with the sections that differ from the root `INTENT.md` and no others, for example:

```md
# Intent

Why this package exists and for whom, where that differs from the repository's [INTENT.md]({relative path}/INTENT.md).

## For whom

- Package: {who changes it}.
- Artifact: {who imports or runs it}.

## Non-goals

- {Each one, one line. For a library: the layers it must never contain. For an app: the logic it must never hold.}
```

## devenv.nix

A package's hooks are the custom `{name}-` hooks of its stack in the `init` skill's `devenv.md` reference (`{name}-basedpyright` for Python, `{name}-tsc` and `{name}-eslint` for TypeScript, `{name}-tflint` for OpenTofu), scoped to the package with `files`.
Stock hooks (`ruff`, `ruff-format`, `terraform-format`) are enabled once in the root `devenv.nix`, never here, because a second package scoping the same stock hook fails evaluation with conflicting `files` values.
The file never enables a language.

A Python library:

```nix
{ ... }:
{
  git-hooks.hooks."{name}-basedpyright" = {
    enable = true;
    name = "{name} basedpyright";
    entry = "basedpyright libs/{name}";
    files = "^libs/{name}/.*\\.pyi?$";
    pass_filenames = false;
  };

  tasks."{name}:test" = {
    description = "Run {name} tests";
    exec = "cd libs/{name} && uv run pytest";
  };
}
```

An infrastructure environment has its tflint hook and no tasks; an HCL infra module has the same file with `infra/modules/{name}`:

```nix
{ config, ... }:
{
  git-hooks.hooks."{name}-tflint" = {
    enable = true;
    name = "{name} tflint";
    entry = "tflint --chdir=infra/environments/{name} --config=${config.devenv.root}/.tflint.hcl";
    files = "^infra/environments/{name}/.*\\.tf$";
    pass_filenames = false;
  };
}
```

An app that runs locally adds a process:

```nix
processes."{name}".exec = "cd apps/{name} && uv run {name}";
```

## Dockerfile

Only for an app whose deployable is an image.
Build from the workspace root so the lockfile is the single source of pinned versions, and copy only the app and the libraries it depends on.
Prefer a `dockerTools` derivation in `devenv.nix` when the stack is packaged with Nix.
