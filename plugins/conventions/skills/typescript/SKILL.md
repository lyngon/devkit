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
- `tsconfig.json` is strict beyond `strict: true` (`noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `verbatimModuleSyntax`, `erasableSyntaxOnly`), and stays strict: no `// @ts-ignore`, `// @ts-expect-error` only with a reason on the same line.
- Plain JavaScript only where TypeScript cannot go (configuration files that the tool reads directly).

## Code

- No `any`, also not through an untyped library or `JSON.parse`. Data from outside the process is `unknown` until parsed by a schema (zod, valibot) in the adapter or entrypoint that receives it.
- Named exports only. A default export hides its name at every import site. The exception is a tool's configuration file (`*.config.ts`), which the tool reads through its default export.
- `import type` for types; the compiler and the bundler then drop them.
- Named imports, except for Node builtins: those carry the `node:` prefix and are imported as a namespace, `import * as fs from "node:fs"`, so no bare `readFile` or `join` appears in the code.
- Only syntax that type stripping erases: no `enum` (a union of string literals instead), no `namespace`, no constructor parameter properties.
- An indexed access (`items[i]`, `record[key]`) may be `undefined`; handle that case, never assert it away with `!`.
- Conditions test booleans. Compare numbers and strings explicitly (`count > 0`, `name !== ""`); a truthiness check treats `0` and `""` as missing.
- A `switch` over a union handles every member, or has a `default` that proves exhaustiveness.
- Errors are `Error` subclasses with a `cause`. Never throw a string or a plain object.
- Prefer `readonly` and immutable updates; mutate only inside the function that owns the value.
- No classes for data. Objects and functions, with interfaces for the shapes.
- Domain and application code imports no framework, no runtime API and no generated client.

## Tests

- vitest, in `tests/` or next to the file as `*.test.ts`, one style per package.
- Test names say the behaviour: `it("rejects a second shipment")`.
- Tests import the package through its `exports` map, the way a consumer does.

## With the Lyngon baseline

- Checked by the `prettier` hook and by two hooks per package: `{name}-tsc` type-checks against the root `tsconfig.base.json`, and `{name}-eslint` lints with the root `eslint.config.js` (typescript-eslint `strictTypeChecked` and `stylisticTypeChecked`, plus the import and condition rules above).
- A package's `tsconfig.json` extends `tsconfig.base.json` and never loosens a flag. The root `eslint.config.js` is the only ESLint configuration.
- Silence a single finding with `// eslint-disable-next-line <rule> -- <reason>`. Change the root configuration only with a reason next to the change.

## With the Lyngon structure

- One pnpm workspace at the repository root with explicit members; `pnpm-lock.yaml` at the root pins.
- A core library holds `src/domain/` and `src/application/`, with dependency-cruiser enforcing the direction; `/repo:add-package` writes the rules.
- React and other UI code is an entrypoint or an adapter, never the place where a rule lives.
