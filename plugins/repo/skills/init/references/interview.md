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
- **8. Artifacts.** Which separate artifacts does the repository produce today (one is fine)? Each becomes a package under `packages/`.

### Round 2, typical frontier

- **9. Package names.** One kebab-case name per artifact from Q8, confirming they become `packages/<name>/`.
- **10. Delivery.** For each artifact: container image, registry package (PyPI, npm, crates.io), binary release, docs site, deployed service, or nothing. (Drives CI jobs and `.gitignore`.)
- **11. Git host and CI.** Confirm the host from the inventory or ask. Recommend GitHub with GitHub Actions running `devenv test`.
- **12. Constraints not visible in code.** Compliance, client contracts, target platforms, performance budgets, offline requirements. Each of these is an ADR candidate.
- **13. Secrets.** Does anything in the repository need secrets (API keys, tokens, credentials)? If yes, `secretspec` is wired; ask which secrets by name and which provider (keyring, dotenv, env, onepassword, lastpass) per profile. Do not ask which mechanism; it is always `secretspec`.
- **14. Services.** Does local development need a database, cache, queue or similar? Name each one. Wire a devenv `services.*` entry only for services the user confirms by name.
- **15. Test strategy.** What counts as "tests pass": unit only, integration against services, end-to-end? What should `devenv test` run beyond the hooks?
- **16. Lyngon plugins.** Which plugins from the `lyngon` marketplace does this repository use? `all` is recommended: it bundles every plugin a Lyngon repository uses and keeps adoption to one install command for colleagues. A subset is named plugin by plugin; `repo` brings `discover` with it.

### Round 3 and later, as unblocked

- **17. Terms.** For every domain word that came up more than once with more than one meaning: which is the canonical term, and which words are to be avoided?
- **18. Stack-specific choices** that carry lock-in: ORM or raw SQL, framework, package manager if unusual, Rust channel, Go module path, Terraform backend. Only ask when the answer is not obvious from the inventory.
- **19. Linters with project config.** eslint and clippy need repository-specific configuration and are left commented out in `devenv.nix`. Confirm that, or ask the user to supply the configuration now.
- **20. Existing files in adopt mode.** For each existing file that the baseline would touch: merge, replace, or leave. Show the diff before asking.
- **21. ADR confirmations.** For each ADR candidate collected so far: record it, or not.

## What the answers become

| Answer | Lands in |
| --- | --- |
| Problem, failure in a year, non-goals, lifetime, audiences | `INTENT.md`; `README.md` and `CLAUDE.md` link to it |
| Technologies, artifacts, package names | `packages/<name>/devenv.nix`, root `devenv.yaml` imports, `.gitignore`, `CLAUDE.md` layout |
| Delivery, git host, CI | `.github/workflows/ci.yml` or equivalent, `README.md` |
| Constraints, lock-in choices | `docs/adr/` |
| Secrets | `secretspec.toml`, `devenv.yaml` |
| Services, test strategy | `devenv.nix` (`services.*`, `enterTest`), `CLAUDE.md` checks section |
| Lyngon plugins | `.claude/settings.json` |
| Terms | `CONCEPTS.md` |
| Repository-specific conventions longer than a line | `docs/conventions/<topic>.md` |
| Explicit deferrals | `docs/TODO.md` |
