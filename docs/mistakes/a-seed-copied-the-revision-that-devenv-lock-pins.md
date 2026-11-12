# A seed copied the revision that devenv.lock pins

- **Date**: 2026-11-12
- **Caught in**: [feat(build): deny an OpenTofu command that writes outside build:live-mutation](https://github.com/lyngon/devkit/pull/151)

To give an eval case the OpenTofu and the shfmt of a Lyngon shell, the agent wrote the nixpkgs revision of `devenv.lock` into the case's `seed-workspace.sh` as a literal, with a comment that said it was the lock's pin.
The next update of the lock would leave the seed on the old revision with nothing failing.
`build:comment-auditor` flagged it in review, and the seed now reads the revision from `devenv.lock` with `nix eval`.
