{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Wrapper so the git hook and `devenv test` run the checked-in script with
  # its dependencies on PATH, no matter which shell invoked `git commit`.
  validateMarketplace = pkgs.writeShellApplication {
    name = "validate-marketplace";
    runtimeInputs = [
      pkgs.jq
      pkgs.git
    ];
    text = ''exec "${config.devenv.root}/scripts/validate-marketplace.sh" "$@"'';
  };
in
{
  # Baseline hooks, MCP server file and languages come from ./devenv.
  lyngon.enable = true;

  packages = [
    validateMarketplace
    pkgs.jq
  ];

  # Repository-specific hook.
  git-hooks.hooks.validate-marketplace = {
    enable = true;
    name = "validate marketplace";
    entry = lib.getExe validateMarketplace;
    files = "^(\\.claude-plugin/|plugins/|catalog/|shared/)";
    pass_filenames = false;
  };

  # `devenv test` runs every git hook on every file first, then this.
  enterTest = ''
    validate-marketplace
  '';
}
