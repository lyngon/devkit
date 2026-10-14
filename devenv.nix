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
      pkgs.bash
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
    ];
    text = ''exec "${config.devenv.root}/scripts/validate-marketplace.sh" "$@"'';
  };
  renderPluginList = pkgs.writeShellApplication {
    name = "render-plugin-list";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.gawk
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
    ];
    text = ''exec "${config.devenv.root}/scripts/render-plugin-list.sh" "$@"'';
  };
  # What an agent can read from an installed plugin: every skill reference in
  # it names a skill that exists, the text of `writing` names no other plugin
  # and nothing of a development repository, and a term of the structure
  # stands under the one conditional heading.
  validateShippedText = pkgs.writeShellApplication {
    name = "validate-shipped-text";
    runtimeInputs = [
      pkgs.python3
      pkgs.git
    ];
    text = ''exec "${config.devenv.root}/scripts/validate-shipped-text.py" "$@"'';
  };
  # The eval suite at a base commit and in the working tree, side by side.
  # The program also runs `claude`, which no file declares: it is the harness,
  # and comes from the PATH of whoever runs an eval.
  compareEvals = pkgs.writeShellApplication {
    name = "compare-evals";
    runtimeInputs = [
      pkgs.python3
      pkgs.git
    ];
    text = ''exec "${config.devenv.root}/scripts/compare-evals.py" "$@"'';
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
  # Fixture tests for compare-evals, with a stub in place of `claude`, so that
  # the full check never calls a model.
  testCompareEvals = pkgs.writeShellApplication {
    name = "test-compare-evals";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.git
      pkgs.gnugrep
      pkgs.jq
      pkgs.python3
    ];
    text = ''exec "${config.devenv.root}/scripts/tests/compare-evals.sh" "$@"'';
  };
  # Fixture tests for the baseline module's validate-documents hook.
  testValidateDocuments = pkgs.writeShellApplication {
    name = "test-validate-documents";
    runtimeInputs = [
      pkgs.bash
      pkgs.python3
      pkgs.git
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''exec "${config.devenv.root}/devenv/tests/validate-documents.sh" "$@"'';
  };
  # The validate-documents hook must be handed file names, symbolic links
  # included, in one run, and must run on a commit that only deletes files:
  # an AGENTS.md is usually a link, which a hook does not see by default, a
  # deleted agent file is never among the names, and nothing else fails when
  # that wiring is lost.
  testDocumentsHookWiring = pkgs.writeShellApplication {
    name = "test-documents-hook-wiring";
    runtimeInputs = [
      pkgs.gnugrep
      pkgs.jq
    ];
    text = ''
      if grep -v '^#' "${config.devenv.root}/.pre-commit-config.yaml" |
        jq -e '[.repos[].hooks[] | select(.id == "validate-documents")]
          | length == 1 and .[0].types == [] and .[0].pass_filenames and .[0].require_serial
            and .[0].always_run' >/dev/null; then
        echo "test-documents-hook-wiring: ok"
      else
        echo "test-documents-hook-wiring: the validate-documents hook needs types = [ ], pass_filenames, require_serial and always_run" >&2
        exit 1
      fi
    '';
  };
  # Fixture tests for the baseline module's check-pull-request command, which
  # `enterTest` hands over as it is on the PATH of the shell. commitizen and
  # the tools of prose-lint.sh serve the runs that call the Python file itself.
  testCheckPullRequest = pkgs.writeShellApplication {
    name = "test-check-pull-request";
    runtimeInputs = [
      pkgs.bash
      pkgs.commitizen
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.python3
    ];
    text = ''exec "${config.devenv.root}/devenv/tests/check-pull-request.sh" "$@"'';
  };
  # Fixture tests for the baseline module's validate-structure hook.
  testValidateStructure = pkgs.writeShellApplication {
    name = "test-validate-structure";
    runtimeInputs = [
      pkgs.bash
      pkgs.python3
      pkgs.git
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''exec "${config.devenv.root}/devenv/tests/validate-structure.sh" "$@"'';
  };
  # The baseline's git hooks in the worktrees of a throwaway repository, which
  # the test enters with the devenv that `enterTest` hands over, the one that
  # runs the full check. This repository's lock file pins the throwaway one,
  # so its inputs are the ones that devenv has fetched already.
  testHooksFollowTheirWorktree = pkgs.writeShellApplication {
    name = "test-hooks-follow-their-worktree";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.git
    ];
    text = ''exec "${config.devenv.root}/devenv/tests/hooks-follow-their-worktree.sh" "$@" "${config.devenv.root}/devenv.lock"'';
  };
  testValidateShippedText = pkgs.writeShellApplication {
    name = "test-validate-shipped-text";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.git
      pkgs.gnugrep
      pkgs.jq
      pkgs.python3
    ];
    text = ''exec "${config.devenv.root}/scripts/tests/validate-shipped-text.sh" "$@"'';
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
  # Fixture tests for the devkit plugin's hook script; zsh and bash read back
  # the environment file, as Claude Code's Bash tool does before a command.
  testDevkitHooks = pkgs.writeShellApplication {
    name = "test-devkit-hooks";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.zsh
    ];
    text = ''exec "${config.devenv.root}/plugins/devkit/hooks/tests/hooks.sh" "$@"'';
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

  # Fixture tests for the prune script that the correction skill ships. The
  # test hands the script a PATH of the baseline's lyngon.scriptTools and
  # nothing else, which is all a repository's shell promises a shipped script.
  testPruneMistakes = pkgs.writeShellApplication {
    name = "test-prune-mistakes";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''exec "${config.devenv.root}/plugins/build/tests/prune-mistakes.sh" "${lib.makeBinPath config.lyngon.scriptTools}"'';
  };

  # The workflow templates that repo:init ships, against this repository's own
  # workflows. A run of the workflows here counts as proof of the templates,
  # which holds only while the two read the same. markdown-it-py reads the
  # templates out of the reference, whose fenced blocks nest.
  testWorkflowTemplates = pkgs.writeShellApplication {
    name = "test-workflow-templates";
    runtimeInputs = [
      (pkgs.python3.withPackages (packages: [ packages.markdown-it-py ]))
    ];
    text = ''exec "${config.devenv.root}/scripts/tests/workflow-templates.py" "$@"'';
  };
in
{
  # Baseline hooks, MCP server file, check-pull-request, the tools of shipped
  # scripts and languages come from ./devenv.
  lyngon.enable = true;

  packages = [
    validateMarketplace
    renderPluginList
    validateShippedText
    compareEvals
    pkgs.jq
    # For the eval case of build:correction, whose run proves a lint rule on
    # the Python files it seeds. A command of a run finds what this shell has
    # and nothing else, and an agent that misses ruff runs whichever one it
    # finds in the Nix store.
    pkgs.ruff
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
  git-hooks.hooks.validate-shipped-text = {
    enable = true;
    name = "validate shipped text";
    entry = lib.getExe validateShippedText;
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

  # `devenv test` runs every git hook on every file first, then these. Each
  # runs with an empty PATH, so a tool that a wrapper does not declare fails
  # here and not for whoever commits from a shell that lacks it.
  enterTest = ''
    declared_tools_only() {
      env -i HOME="$HOME" "$@"
    }
    declared_tools_only ${lib.getExe validateMarketplace}
    declared_tools_only ${lib.getExe renderPluginList}
    declared_tools_only ${lib.getExe validateShippedText}
    declared_tools_only ${lib.getExe testValidateMarketplace}
    declared_tools_only ${lib.getExe testCompareEvals}
    declared_tools_only ${lib.getExe testValidateDocuments}
    declared_tools_only ${lib.getExe testDocumentsHookWiring}
    declared_tools_only ${lib.getExe testCheckPullRequest} "$(command -v check-pull-request)"
    declared_tools_only ${lib.getExe testValidateStructure}
    declared_tools_only ${lib.getExe testHooksFollowTheirWorktree} "$(command -v devenv)"
    declared_tools_only ${lib.getExe testValidateShippedText}
    declared_tools_only ${lib.getExe testRepoHooks}
    declared_tools_only ${lib.getExe testDevkitHooks}
    declared_tools_only ${lib.getExe testBuildScripts}
    declared_tools_only ${lib.getExe testPruneMistakes}
    declared_tools_only ${lib.getExe testWorkflowTemplates}
  '';
}
