# Package files

Templates for the files every app and library carries.
Replace every `{placeholder}` and leave no template comments behind.

## INTENT.md

Same shape as the repository's, under thirty lines.

```md
# Intent

Why this package exists and for whom.

## Product

**{name}** {one or two sentences: what it is and what it does for the context}.
{For an app: the deployable kind (image, web bundle, binary, function package) and the runtime units it backs.}

## For whom

- Package: {who changes it}.
- Artifact: {who imports or runs it}.

## Done means

- {Two or three observable outcomes.}

## Failure means

- {Two or three observable outcomes.}

## Non-goals

- {Each one, one line. For a library: the layers it must never contain. For an app: the logic it must never hold.}

## Horizon

{Throwaway, months, or years}. {One sentence.}
```

## README.md

```md
# {name}

{One paragraph: what it is. Link to INTENT.md.}

## Run

{How to run or use it from the devenv shell, one command per line in a code block.}

## Test

{The test command.}
```

## CLAUDE.md

Only what differs from the root; the root file is loaded in every session already.

````md
# {name}

{One sentence.} Part of the `{ctx}` context; terms are in [{relative path}/CONCEPTS.md]({relative path}/CONCEPTS.md).
Why it exists is in [INTENT.md](INTENT.md).

## Checks

```sh
{package test command, e.g. cd libs/orders && uv run pytest}
```

## Layout

{For a core library: `domain/` holds the model and its rules and imports no other layer; `application/` holds use cases and ports and imports domain only. Neither imports a contract, an adapter or an app; the lint enforces it.}
{For an adapter: which port it implements and against which technology.}
{For an app: what it wires together; no logic lives here.}

## Conventions

{Only conventions specific to this package. Omit the section when there are none.}
````

Then:

```sh
ln -sfn CLAUDE.md AGENTS.md
```

## devenv.nix

```nix
{ ... }:
{
  git-hooks.hooks = {
    ruff-format = {
      enable = true;
      files = "^libs/{name}/";
    };
    ruff = {
      enable = true;
      files = "^libs/{name}/";
    };
  };

  tasks."{name}:test" = {
    description = "Run {name} tests";
    exec = "cd libs/{name} && uv run pytest";
  };
}
```

Formatter and linter hooks per stack are in the `init` skill's `devenv.md` reference; the package file scopes them with `files` and never enables a language.
An app that runs locally adds a process:

```nix
processes."{name}".exec = "cd apps/{name} && uv run {name}";
```

## Dockerfile

Only for an app whose deployable is an image.
Build from the workspace root so the lockfile is the single source of pinned versions, and copy only the app and the libraries it depends on.
Prefer a `dockerTools` derivation in `devenv.nix` when the stack is packaged with Nix.
