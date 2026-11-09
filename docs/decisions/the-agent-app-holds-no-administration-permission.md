# The agent App holds no administration permission

An agent must not be able to edit the rules that bind it, so an agent App holds the permissions a contributor needs and none that changes a repository's settings, rulesets or branch protection, which an owner applies as themselves.
The baseline's manifest template states those permissions for every App created from it, and `agent-identity` refuses a token that holds a permission the template does not grant, so a permission added on GitHub alone stops the agents instead of widening what they can do.

## Considered options

- `workflows: write` is granted: without it GitHub rejects every push that touches `.github/workflows/`, and the owner reviews each pull request anyway.
- `actions: write` is withheld: re-running a failed job until it passes comes too close to getting past a check.
- A token narrowed to the session's own repository: rejected, because the issue pipeline files issues on the devkit from other repositories of the same owner.

Enforced by: agent-identity and judgment
