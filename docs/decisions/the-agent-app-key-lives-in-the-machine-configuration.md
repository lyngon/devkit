# The agent App's key lives in the machine's configuration

The agent App's private key belongs to a machine, not to a repository: one key serves every repository on the machine, so it is never declared in a repository's `secretspec.toml` and never enters a repository.
Each machine that runs agent sessions gets the key through sops-nix in its owner's Nix configuration, readable only by the person who runs the sessions, and the variable `LYNGON_AGENT_KEY_FILE` names the file.
A machine without the key has no agent identity, so its agents cannot reach GitHub.

Enforced by: judgment
