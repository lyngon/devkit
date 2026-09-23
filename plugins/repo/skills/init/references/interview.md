# The interview

The method (design tree, rounds, frontier, recommended answers) is `discover:interview`; invoke it first.
This file holds what is specific to repository setup.

## Rules

- Challenge vague ideas the moment they appear. "A tool for data" is not a purpose. Ask what breaks without it.
- When a term is overloaded or two words are used for one thing, stop and settle it with `discover:domain-model`, which writes the `CONCEPTS.md` entry as soon as it settles.
- Never ask what the inventory already answered.
- Do not create `docs/TODO.md` items for questions the user left open. Only what the user explicitly says to defer goes there.
- Offer an ADR only for decisions that meet the three criteria in `discover:domain-model`; say which decision you intend to record and why.

## Question catalog

Round 1 is fixed.
Later rounds are frontier-driven; the catalog lists the questions that usually appear and what they unblock.
Adapt wording to the repository.

### Round 1, always

- **1. Failure in a year.** What would make this repository a failure twelve months from now? (Asked first because it exposes vague purposes fastest.)
- **2. Problem.** What goes wrong today without this repository? What is it solving, for whom?
- **3. Non-goals.** What will this repository explicitly not do, even if asked?
- **4. Lifetime.** Throwaway, months, or years? (Drives how much structure is worth.)
- **5. Repository audience.** Who reads and changes the repository: a single owner, a team, other Lyngon teams, clients, the public? (Drives license, README depth, CoC and security policy.)
- **6. Artifact audience.** Who consumes what the repository produces: end users, other services, other repositories, agents? (Drives README "usage" sections and delivery questions.)
- **7. Technologies.** Which languages, frameworks and runtimes are involved, or already present per the inventory? Supported stacks: Python (uv), TypeScript (pnpm), Rust, Go, Nix, Shell, Terraform, Haskell. Anything else is handled generically.
- **8. Scope.** Which of the Lyngon prerequisites does this repository adopt: the documents only (`INTENT.md`, `CLAUDE.md`, `CONCEPTS.md`, ADRs), the documents and the baseline (devenv with `lyngon/devenv` imported), or all three including the structure from `STRUCTURE.md`? Recommend all three for a repository Lyngon owns; documents only for one that must keep its own toolchain and layout. Every later question about packages, devenv, secrets and services is skipped when its scope was not adopted.
- **9. Artifacts.** (Scope includes the structure.) Which separate artifacts does the repository produce today (one is fine)? Each becomes a package; its kind (app, library, contract, tool, infra module) decides its directory, per `STRUCTURE.md`.

### Round 2, typical frontier

- **10. Contexts and package names.** (Scope includes the structure.) Which bounded context does each artifact from Q9 belong to (one is fine)? The context becomes the name prefix and gets a core library under `libs/<ctx>/`; each artifact gets a kind and a context-prefixed kebab-case name, so `apps/orders-api/`, `libs/orders/`, `libs/orders-postgres/`.
- **11. Delivery.** For each artifact: container image, registry package (PyPI, npm, crates.io), binary release, docs site, deployed service, or nothing. (Drives CI jobs and `.gitignore`.)
- **12. Git host and CI.** Confirm the host from the inventory or ask. Recommend GitHub with GitHub Actions running `devenv test` (or the repository's own check, when devenv was not adopted).
- **13. Constraints not visible in code.** Compliance, client contracts, target platforms, performance budgets, offline requirements. Each of these is an ADR candidate.
- **14. Secrets.** (Scope includes the baseline.) Does anything in the repository need secrets (API keys, tokens, credentials)? If yes, `secretspec` is wired; ask which secrets by name and which provider (keyring, dotenv, env, onepassword, lastpass) per profile. Do not ask which mechanism; it is always `secretspec`.
- **15. Services.** (Scope includes the baseline.) Does local development need a database, cache, queue or similar? Name each one. Wire a devenv `services.*` entry only for services the user confirms by name.
- **16. Test strategy.** What counts as "tests pass": unit only, integration against services, end-to-end? What should `devenv test` run beyond the hooks?
- **17. Lyngon plugins.** Which plugins from the `lyngon` marketplace does this repository use? `all` when the scope is all three prerequisites, `core` (`discover`, `writing`, `conventions`) when it is the documents only; both keep adoption to one install command for colleagues. A subset is named plugin by plugin; `repo` brings `discover` with it.

### Round 3 and later, as unblocked

- **18. Terms.** For every domain word that came up more than once with more than one meaning: which is the canonical term, and which words are to be avoided?
- **19. Stack-specific choices** that carry lock-in: ORM or raw SQL, framework, package manager if unusual, Rust channel, Go module path, Terraform backend. Only ask when the answer is not obvious from the inventory.
- **20. Linters with project config.** eslint and clippy need repository-specific configuration and are left commented out in `devenv.nix`. Confirm that, or ask the user to supply the configuration now.
- **21. Existing files in adopt mode.** For each existing file that the baseline would touch: merge, replace, or leave. Show the diff before asking.
- **22. ADR confirmations.** For each ADR candidate collected so far: record it, or not.

## What the answers become

| Answer | Lands in |
| --- | --- |
| Problem, failure in a year, non-goals, lifetime, audiences | `INTENT.md`; `README.md` and `CLAUDE.md` link to it |
| Scope | which of the file sets below are written; the `CLAUDE.md` structure sentence and `lyngon.structure.enable` when the structure is adopted |
| Technologies, artifacts, contexts, package names | root workspace files and `languages.*`, one `add-package` invocation per package, root `devenv.yaml` imports, `.gitignore`, `CLAUDE.md` layout |
| Delivery, git host, CI | `.github/workflows/ci.yml` or equivalent, `README.md` |
| Constraints, lock-in choices | `docs/adr/` |
| Secrets | `secretspec.toml`, `devenv.yaml` |
| Services, test strategy | `devenv.nix` (`services.*`, `enterTest`), `CLAUDE.md` checks section |
| Lyngon plugins | `.claude/settings.json` |
| Terms | `CONCEPTS.md` |
| Repository-specific conventions longer than a line | `docs/conventions/<topic>.md` |
| Explicit deferrals | `docs/TODO.md` |
