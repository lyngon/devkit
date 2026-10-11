# Source playbooks

The why skill searches one source per available evidence category, each with the playbook below when the category has one.
The playbooks are concrete examples for one source.
Adapt them for a different source in the same category.

| Category | Playbook | Source it documents |
| --- | --- | --- |
| Source control history | [`code-archaeology.md`](./sources/code-archaeology.md) | Decision records, git, `gh` |
| Issue / ticket tracker | [`github-issues.md`](./sources/github-issues.md) | GitHub Issues through `gh` (adapt for Linear, Jira, Plane, Shortcut) |
| Long-form documents | None | |
| Real-time team chat | None | |
| Infrastructure observability | None | |
| Error / exception tracking | None | |
| Product analytics warehouse | None | |

An investigator for a category without a playbook works from the base prompt and from what its MCP says about its own tools.
It reports which tools it used and every query it ran.

Cross-cutting:

- [`incident-postmortem.md`](./sources/incident-postmortem.md). Add this if the target code looks defensive (null checks, retry, timeout, rate limit, feature flag, egress guard, OOM handler).
