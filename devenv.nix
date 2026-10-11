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
      pkgs.gawk
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
  # The plugin prerequisites convention in docs/conventions/prerequisites.md.
  validatePrerequisites = pkgs.writeShellApplication {
    name = "validate-prerequisites";
    runtimeInputs = [
      pkgs.python3
      pkgs.git
    ];
    text = ''exec "${config.devenv.root}/scripts/validate-prerequisites.py" "$@"'';
  };
  testValidateMarketplace = pkgs.writeShellApplication {
    name = "test-validate-marketplace";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
    ];
    text = ''exec "${config.devenv.root}/scripts/tests/validate-marketplace.sh" "$@"'';
  };
  # Fixture tests for the baseline module's validate-documents hook.
  testValidateDocuments = pkgs.writeShellApplication {
    name = "test-validate-documents";
    runtimeInputs = [
      pkgs.python3
      pkgs.git
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''exec "${config.devenv.root}/devenv/tests/validate-documents.sh" "$@"'';
  };
  # The validate-documents hook must be handed file names, symbolic links
  # included, in one run: an AGENTS.md is usually a link, which a hook does
  # not see by default, and nothing else fails when that wiring is lost.
  testDocumentsHookWiring = pkgs.writeShellApplication {
    name = "test-documents-hook-wiring";
    runtimeInputs = [
      pkgs.gnugrep
      pkgs.jq
    ];
    text = ''
      if grep -v '^#' "${config.devenv.root}/.pre-commit-config.yaml" |
        jq -e '[.repos[].hooks[] | select(.id == "validate-documents")]
          | length == 1 and .[0].types == [] and .[0].pass_filenames and .[0].require_serial' >/dev/null; then
        echo "test-documents-hook-wiring: ok"
      else
        echo "test-documents-hook-wiring: the validate-documents hook needs types = [ ], pass_filenames and require_serial" >&2
        exit 1
      fi
    '';
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
  testValidatePrerequisites = pkgs.writeShellApplication {
    name = "test-validate-prerequisites";
    runtimeInputs = [
      pkgs.python3
      pkgs.git
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
    ];
    text = ''exec "${config.devenv.root}/scripts/tests/validate-prerequisites.sh" "$@"'';
  };
  # Fixture tests for the repo plugin's hook scripts; zsh reads back the
  # environment file, as Claude Code's Bash tool does in a zsh session.
  testRepoHooks = pkgs.writeShellApplication {
    name = "test-repo-hooks";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      pkgs.zsh
    ];
    text = ''exec "${config.devenv.root}/plugins/repo/hooks/tests/hooks.sh" "$@"'';
  };

  # Fixture tests for the build plugin's scripts. perl provides shasum, so
  # the tests can run pin with each hash tool alone.
  testBuildScripts = pkgs.writeShellApplication {
    name = "test-build-scripts";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.diffutils
      pkgs.gawk
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      pkgs.perl
    ];
    text = ''exec "${config.devenv.root}/plugins/build/tests/scripts.sh" "$@"'';
  };
in
{
  # Baseline hooks, MCP server file and languages come from ./devenv.
  lyngon.enable = true;

  packages = [
    validateMarketplace
    renderPluginList
    validatePrerequisites
    pkgs.jq
  ];

  # Eval prompts and graders have a fixed shape (frontmatter, then the prompt
  # or rubric as the body) that cannot start with a heading. The first entry
  # repeats the baseline's, which a list set here replaces.
  git-hooks.hooks.markdownlint.excludes = [
    "^\\.claude/CLAUDE\\.md$"
    "^plugins/[^/]+/evals/"
  ];

  # Repository-specific hooks.
  git-hooks.hooks.validate-marketplace = {
    enable = true;
    name = "validate marketplace";
    entry = lib.getExe validateMarketplace;
    files = "^(\\.claude-plugin/|plugins/|catalog/|shared/)";
    pass_filenames = false;
  };
  git-hooks.hooks.validate-prerequisites = {
    enable = true;
    name = "validate prerequisites";
    entry = lib.getExe validatePrerequisites;
    files = "^(\\.claude-plugin/marketplace\\.json$|plugins/|shared/)";
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
    validate-prerequisites
    ${lib.getExe testValidateMarketplace}
    ${lib.getExe testValidateDocuments}
    ${lib.getExe testDocumentsHookWiring}
    ${lib.getExe testValidateStructure}
    ${lib.getExe testValidatePrerequisites}
    ${lib.getExe testRepoHooks}
    ${lib.getExe testBuildScripts}
  '';
}
