---
name: typescript
description: Lyngon TypeScript and JavaScript conventions. Background knowledge, loaded automatically while working on TypeScript and JavaScript files.
user-invocable: false
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.mts"
  - "**/*.cts"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.mjs"
  - "**/*.cjs"
---

# TypeScript conventions

## Project

- pnpm manages everything: `pnpm add`, `pnpm install`, `pnpm --filter <package> run`. Never `npm`, never `yarn`, never `npx` of an unpinned package.
- Internal dependencies use `workspace:*`; the workspace lockfile pins.
- ES modules only: `"type": "module"`, `import` and `export`, no `require`.
- Every package declares an `exports` map; nothing outside it is importable.
- `tsconfig.json` is strict, and stays strict: no `// @ts-ignore`, `// @ts-expect-error` only with a reason on the same line.
- Plain JavaScript only where TypeScript cannot go (configuration files that the tool reads directly).

## Code

- No `any`. Data from outside the process is `unknown` until parsed by a schema (zod, valibot) in the adapter or entrypoint that receives it.
- Named exports only. A default export hides its name at every import site.
- `import type` for types; the compiler and the bundler then drop them.
- Errors are `Error` subclasses with a `cause`. Never throw a string or a plain object.
- Prefer `readonly` and immutable updates; mutate only inside the function that owns the value.
- No classes for data. Objects and functions, with interfaces for the shapes.
- Domain and application code imports no framework, no runtime API and no generated client.

## Tests

- vitest, in `tests/` or next to the file as `*.test.ts`, one style per package.
- Test names say the behaviour: `it("rejects a second shipment")`.
- Tests import the package through its `exports` map, the way a consumer does.

## With the Lyngon baseline

Checked by the `prettier` hook, and `eslint` once the package enables it.

## With the Lyngon structure

- One pnpm workspace at the repository root with explicit members; `pnpm-lock.yaml` at the root pins.
- A core library holds `src/domain/` and `src/application/`, with dependency-cruiser enforcing the direction; `/repo:add-package` writes the rules.
- React and other UI code is an entrypoint or an adapter, never the place where a rule lives.
