# An agent App's key is a file only the operator can read

An agent App's private key belongs to the operator's machine, not to a repository.
It serves every repository on the machine, so it is never declared in a repository's `secretspec.toml` and never enters a repository.
Each App the machine declares has its own key file, which only the operator can read, and the machine's declaration names it.
How the file gets there is the machine's business.
At Lyngon it is sops-nix in the owner's Nix configuration, with one key per machine, so that a lost machine is revoked alone.

Enforced by: agent-identity, which refuses a key file that anyone but its owner can read, and judgment
