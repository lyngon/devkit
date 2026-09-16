# The Lyngon baseline for every repository: git hooks, the devenv MCP server
# file, and the languages every Lyngon repository has (Nix, shell).
#
# Consumers add this repository as an input and import this directory:
#
#   inputs:
#     lyngon:
#       url: github:lyngon/devkit
#       flake: false
#     git-hooks:
#       url: github:cachix/git-hooks.nix
#       inputs:
#         nixpkgs:
#           follows: nixpkgs
#   imports:
#     - lyngon/devenv
#
# and set `lyngon.enable = true;` in devenv.nix. Every baseline value is a
# default, so a repository can override one hook with a comment saying why:
#
#   git-hooks.hooks.typos.enable = false; # false positives in fixtures/
#
# A remote import's devenv.yaml is not merged, so the git-hooks input must be
# declared by the consumer.
{
  lib,
  config,
  ...
}:
let
  cfg = config.lyngon;
in
{
  options.lyngon = {
    enable = lib.mkEnableOption "the Lyngon baseline";

    mcp.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate .mcp.json with the devenv MCP server for Claude Code.";
    };
  };

  config = lib.mkIf cfg.enable {
    languages.nix.enable = lib.mkDefault true;
    languages.shell.enable = lib.mkDefault true;

    # devenv generates .mcp.json (gitignored). .claude/settings.json is a
    # committed, hand-maintained file.
    files.".mcp.json".json = lib.mkIf cfg.mcp.enable {
      mcpServers.devenv = {
        type = "stdio";
        command = "devenv";
        args = [ "mcp" ];
        env.DEVENV_ROOT = config.devenv.root;
      };
    };

    git-hooks.hooks = {
      nixfmt.enable = lib.mkDefault true;
      shellcheck.enable = lib.mkDefault true;
      markdownlint = {
        enable = lib.mkDefault true;
        settings.configuration = lib.mkDefault {
          default = true;
          # Semantic line breaks: one sentence per line, no length limit.
          MD013 = false;
          MD024.siblings_only = true;
        };
      };
      ripsecrets.enable = lib.mkDefault true;
      typos.enable = lib.mkDefault true;
      end-of-file-fixer = {
        enable = lib.mkDefault true;
        excludes = lib.mkDefault [ "devenv.lock" ];
      };
      trim-trailing-whitespace.enable = lib.mkDefault true;
      check-merge-conflicts.enable = lib.mkDefault true;
      commitizen.enable = lib.mkDefault true;
      actionlint.enable = lib.mkDefault true;
      yamllint = {
        enable = lib.mkDefault true;
        settings.preset = lib.mkDefault "relaxed";
      };
    };
  };
}
