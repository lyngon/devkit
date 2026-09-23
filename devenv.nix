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
  renderPluginList = pkgs.writeShellApplication {
    name = "render-plugin-list";
    runtimeInputs = [
      pkgs.jq
      pkgs.git
      pkgs.gawk
    ];
    text = ''exec "${config.devenv.root}/scripts/render-plugin-list.sh" "$@"'';
  };
  # Fixture tests for the baseline module's validate-structure hook.
  testValidateStructure = pkgs.writeShellApplication {
    name = "test-validate-structure";
    runtimeInputs = [
      pkgs.python3
      pkgs.git
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''exec "${config.devenv.root}/devenv/tests/validate-structure.sh" "$@"'';
  };
in
{
  # Baseline hooks, MCP server file and languages come from ./devenv.
  lyngon.enable = true;

  packages = [
    validateMarketplace
    renderPluginList
    pkgs.jq
  ];

  # Eval prompts and graders have a fixed shape (frontmatter, then the prompt
  # or rubric as the body) that cannot start with a heading.
  git-hooks.hooks.markdownlint.excludes = [ "^plugins/[^/]+/evals/" ];

  # Repository-specific hooks.
  git-hooks.hooks.validate-marketplace = {
    enable = true;
    name = "validate marketplace";
    entry = lib.getExe validateMarketplace;
    files = "^(\\.claude-plugin/|plugins/|catalog/|shared/)";
    pass_filenames = false;
  };
  git-hooks.hooks.render-plugin-list = {
    enable = true;
    name = "render plugin list";
    entry = lib.getExe renderPluginList;
    files = "^(\\.claude-plugin/marketplace\\.json|README\\.md|plugins/[^/]+/(\\.claude-plugin/plugin\\.json|skills/[^/]+/SKILL\\.md))$";
    pass_filenames = false;
  };

  # `devenv test` runs every git hook on every file first, then these.
  enterTest = ''
    validate-marketplace
    render-plugin-list
    ${lib.getExe testValidateStructure}
  '';
}
