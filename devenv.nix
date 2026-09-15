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
  packages = [
    validateMarketplace
    pkgs.jq
  ];

  languages.nix.enable = true;
  languages.shell.enable = true;

  # devenv generates .mcp.json (gitignored). .claude/settings.json is a
  # committed, hand-maintained file. See docs/adr/0003.
  files.".mcp.json".json = {
    mcpServers.devenv = {
      type = "stdio";
      command = "devenv";
      args = [ "mcp" ];
      env.DEVENV_ROOT = config.devenv.root;
    };
  };

  git-hooks.hooks = {
    # Lyngon baseline, identical in every repository.
    nixfmt.enable = true;
    shellcheck.enable = true;
    markdownlint = {
      enable = true;
      settings.configuration = {
        default = true;
        # Semantic line breaks: one sentence per line, no length limit.
        MD013 = false;
        MD024.siblings_only = true;
      };
    };
    ripsecrets.enable = true;
    typos.enable = true;
    end-of-file-fixer = {
      enable = true;
      excludes = [ "devenv.lock" ];
    };
    trim-trailing-whitespace.enable = true;
    check-merge-conflicts.enable = true;
    commitizen.enable = true;
    actionlint.enable = true;
    yamllint = {
      enable = true;
      settings.preset = "relaxed";
    };

    # Repository-specific.
    validate-marketplace = {
      enable = true;
      name = "validate marketplace";
      entry = lib.getExe validateMarketplace;
      files = "^(\\.claude-plugin/|plugins/|catalog/)";
      pass_filenames = false;
    };
  };

  # `devenv test` runs every git hook on every file first, then this.
  enterTest = ''
    validate-marketplace
  '';
}
