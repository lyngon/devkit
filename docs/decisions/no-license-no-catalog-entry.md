# No license, no catalog entry

Many published agent skills have no license file, which legally means all rights reserved, so vendoring one copies it without permission and pinning one redistributes it through our marketplace, however short the file is.
A skill without a license therefore enters the catalog neither pinned nor vendored, and `/devkit:add-skill` drafts a request to the author for a license, or for written permission, instead.
The cost is that useful skills stay out until their authors answer; the alternative is a catalog whose word "vetted" does not cover the first question a lawyer would ask.

## Consequences

- `validate-marketplace` fails a plugin that holds vendored text without a link to the license of its upstream, but only judgment keeps an agent from writing a license file that the upstream never published.

Enforced by: validate-marketplace and judgment
