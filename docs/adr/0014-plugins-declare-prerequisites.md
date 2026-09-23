# Plugins declare their prerequisites, and text above them is allowed only in conditional sections

The devkit's opinions (the document set, devenv, the kind-first layout) leaked from the `repo` plugin into `discover` and `conventions` through shared documents and prose, so a repository that only wanted discovery or the language conventions would have been told to follow the layout and run `devenv test`.
We make the prerequisites explicit: every plugin README declares which of `documents`, `devenv` and `structure` the plugin needs, the three being independent rather than a ladder, and a validator checks the plugin's text lexically against the declaration, the same way `prose-lint` checks for dashes.
Text about an undeclared prerequisite is allowed only under a heading `With the Lyngon documents`, `With devenv` or `With the Lyngon structure`, which an agent reads as "only if the repository has this"; the alternative, one plugin per prerequisite, would double the plugin count and every repository would still install both or neither.

## Consequences

- `discover` and `conventions` declare `documents`; `writing` declares nothing; `repo` and `devkit` declare all three. A `core` bundle installs the first three, and the validator checks that a bundle's declaration is the union of its members'.
- `init` asks which prerequisites a repository adopts and writes only those file sets. A repository that adopted the structure says so in its root `CLAUDE.md` and sets `lyngon.structure.enable`; the session hook, `add-package` and the `validate-structure` hook all read that marker.
- Skills that load by `paths` and the session hook are held to the rule most strictly, because they speak without being asked.
- The rules are in `docs/conventions/prerequisites.md`; changing the term lists there changes what the validator catches.
