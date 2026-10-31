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
  # The commit hooks of the two validators above run them on a checkout of
  # the index, because prek leaves untracked files in the working tree while
  # the hooks run, and a file that a commit leaves out must not decide it
  # (issue 94).
  onTheIndex = pkgs.writeShellApplication {
    name = "on-the-index";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.git
    ];
    text = ''exec "${config.devenv.root}/scripts/on-the-index.sh" "$@"'';
  };
  # The eval suite at a base commit and in the working tree, side by side.
  # The program also runs `claude` and `devenv`, which no file declares: the
  # harness, and the tool that made the shell the program starts from. Both
  # come from the PATH of whoever runs an eval.
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
  # Fixture tests for compare-evals, with stubs in place of `claude` and
  # `devenv`, so that the full check never calls a model or builds an
  # environment.
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
  # The baseline's .mcp.json in a throwaway repository, entered as the hooks
  # test above enters its own.
  testMcpFileFollowsItsOption = pkgs.writeShellApplication {
    name = "test-mcp-file-follows-its-option";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
    ];
    text = ''exec "${config.devenv.root}/devenv/tests/mcp-file-follows-its-option.sh" "$@" "${config.devenv.root}/devenv.lock"'';
  };
  # The commit hooks of the two validators, as the configuration defines
  # them, in throwaway repositories that commit through prek, which
  # `enterTest` hands over with the configuration.
  testValidatorsCheckTheCommit = pkgs.writeShellApplication {
    name = "test-validators-check-the-commit";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.git
      pkgs.gnugrep
      pkgs.jq
    ];
    text = ''exec "${config.devenv.root}/scripts/tests/validators-check-the-commit.sh" "$@"'';
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
  # Fixture tests for the build plugin's hook script, which needs bash alone.
  testBuildHooks = pkgs.writeShellApplication {
    name = "test-build-hooks";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
    ];
    text = ''exec "${config.devenv.root}/plugins/build/tests/hooks.sh" "$@"'';
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

  # Fixture tests for the helper that the work-trace skill ships, run with the
  # same PATH as the prune script's.
  testWorkTrace = pkgs.writeShellApplication {
    name = "test-work-trace";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
    ];
    text = ''exec "${config.devenv.root}/plugins/build/tests/work-trace.sh" "${lib.makeBinPath config.lyngon.scriptTools}"'';
  };

  # Fixture tests for the stand-in for gh that the eval cases of build:pull-request
  # run, in a workspace that their seed script writes.
  testEvalForge = pkgs.writeShellApplication {
    name = "test-eval-forge";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.git
      pkgs.jq
      pkgs.python3
    ];
    text = ''exec "${config.devenv.root}/plugins/build/tests/eval-forge.sh" "$@"'';
  };

  # markdown-it-py reads the workflow templates out of the reference of
  # repo:init, whose fenced blocks nest.
  pythonWithMarkdownIt = pkgs.python3.withPackages (packages: [ packages.markdown-it-py ]);

  # The workflow templates that repo:init ships, against this repository's own
  # workflows. A run of the workflows here counts as proof of the templates,
  # which holds only while the two read the same.
  testWorkflowTemplates = pkgs.writeShellApplication {
    name = "test-workflow-templates";
    runtimeInputs = [ pythonWithMarkdownIt ];
    text = ''exec "${config.devenv.root}/scripts/tests/workflow-templates.py" "$@"'';
  };

  # The marketplace declaration in .claude/settings.json against the settings
  # template of repo:init, and the plugin folder that this shell hands Claude
  # Code against this checkout, which `enterTest` passes as an argument.
  testCheckoutPlugins = pkgs.writeShellApplication {
    name = "test-checkout-plugins";
    runtimeInputs = [ pythonWithMarkdownIt ];
    text = ''exec "${config.devenv.root}/scripts/tests/checkout-plugins.py" "$@"'';
  };

  # The type check of this repository's Python programs, as the table
  # [tool.basedpyright] of pyproject.toml sets it. basedpyright resolves an
  # import through the interpreter it is given, and the test of the workflow
  # templates imports markdown_it.
  basedpyright = pkgs.writeShellApplication {
    name = "basedpyright";
    text = ''exec ${lib.getExe' pkgs.basedpyright "basedpyright"} --pythonpath ${lib.getExe' pythonWithMarkdownIt "python3"} "$@"'';
  };
in
{
  # Baseline hooks, check-pull-request, the tools of shipped scripts and
  # languages come from ./devenv. The devenv MCP server stays off as in any
  # repository: sessions here are many at once and barely use its tools.
  lyngon.enable = true;

  # A session started from this shell loads every plugin of this checkout, each
  # in place of the installed plugin of its name. Claude Code keeps one
  # registration of the marketplace lyngon per user, and every Lyngon
  # repository declares it from GitHub, so a declaration from this working tree
  # moved that registration back and forth between sessions here and elsewhere
  # (issue 83). Project settings cannot set this variable; Claude Code 2.1.280
  # and later read it.
  env.CLAUDE_CODE_PLUGIN_DIRS = "${config.devenv.root}/plugins";

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
    # The type check that the hook below runs, for a run by hand.
    basedpyright
  ];

  # Eval prompts and graders have a fixed shape (frontmatter, then the prompt
  # or rubric as the body) that cannot start with a heading. The first entry
  # repeats the baseline's, which a list set here replaces.
  git-hooks.hooks.markdownlint.excludes = [
    "^\\.claude/CLAUDE\\.md$"
    "^plugins/[^/]+/evals/"
  ];

  # Repository-specific hooks. The two validators run on every commit, with no
  # filter on files: a commit that only deletes files or only stages links
  # hands a hook no file to match, and can still break what they check
  # (issue 97).
  git-hooks.hooks.validate-marketplace = {
    enable = true;
    name = "validate marketplace";
    entry = "${lib.getExe onTheIndex} ${lib.getExe validateMarketplace}";
    always_run = true;
    pass_filenames = false;
  };
  git-hooks.hooks.validate-shipped-text = {
    enable = true;
    name = "validate shipped text";
    entry = "${lib.getExe onTheIndex} ${lib.getExe validateShippedText}";
    always_run = true;
    pass_filenames = false;
  };
  git-hooks.hooks.render-plugin-list = {
    enable = true;
    name = "render plugin list";
    entry = lib.getExe renderPluginList;
    files = "^(\\.claude-plugin/marketplace\\.json|README\\.md|plugins/[^/]+/(\\.claude-plugin/plugin\\.json|skills/[^/]+/SKILL\\.md))$";
    pass_filenames = false;
  };

  # This repository's Python programs, against ruff.toml and pyproject.toml.
  # Here and not in the baseline: a program under devenv/ reaches another
  # repository as a file in the Nix store, where no hook of that repository
  # reads it. The eval cases seed their files into a run as the code of an
  # imagined repository, some with a fault on purpose, and one carries a
  # ruff.toml of its own, which ruff follows for a file named to it.
  git-hooks.hooks.ruff = {
    enable = true;
    excludes = [ "^plugins/[^/]+/evals/" ];
  };
  git-hooks.hooks.ruff-format = {
    enable = true;
    excludes = [ "^plugins/[^/]+/evals/" ];
  };
  git-hooks.hooks.basedpyright = {
    enable = true;
    name = "basedpyright";
    entry = lib.getExe basedpyright;
    # One run over every program, also when the configuration changes.
    files = "(\\.pyi?|^pyproject\\.toml)$";
    excludes = [ "^plugins/[^/]+/evals/" ];
    pass_filenames = false;
  };
  # ruff.toml names the rule CPY001, and typos reads its prefix as a
  # misspelling of COPY.
  git-hooks.hooks.typos.settings.ignored-words = [ "CPY" ];

  # `devenv test` runs every git hook on every file first, then these. Each
  # runs with an empty PATH, so a tool that a wrapper does not declare fails
  # here and not for whoever commits from a shell that lacks it.
  enterTest = ''
    declared_tools_only() {
      env -i HOME="$HOME" "$@"
    }
    declared_tools_only ${lib.getExe validateMarketplace}
    declared_tools_only ${lib.getExe onTheIndex} ${lib.getExe validateMarketplace}
    declared_tools_only ${lib.getExe renderPluginList}
    declared_tools_only ${lib.getExe validateShippedText}
    declared_tools_only ${lib.getExe onTheIndex} ${lib.getExe validateShippedText}
    declared_tools_only ${lib.getExe testValidateMarketplace}
    declared_tools_only ${lib.getExe testValidatorsCheckTheCommit} ${lib.getExe config.git-hooks.package} "${config.devenv.root}/${config.git-hooks.configPath}"
    declared_tools_only ${lib.getExe testCompareEvals}
    declared_tools_only ${lib.getExe testValidateDocuments}
    declared_tools_only ${lib.getExe testDocumentsHookWiring}
    declared_tools_only ${lib.getExe testCheckPullRequest} "$(command -v check-pull-request)"
    declared_tools_only ${lib.getExe testValidateStructure}
    declared_tools_only ${lib.getExe testHooksFollowTheirWorktree} "$(command -v devenv)"
    declared_tools_only ${lib.getExe testMcpFileFollowsItsOption} "$(command -v devenv)"
    declared_tools_only ${lib.getExe testValidateShippedText}
    declared_tools_only ${lib.getExe testRepoHooks}
    declared_tools_only ${lib.getExe testDevkitHooks}
    declared_tools_only ${lib.getExe testBuildHooks}
    declared_tools_only ${lib.getExe testPruneMistakes}
    declared_tools_only ${lib.getExe testWorkTrace}
    declared_tools_only ${lib.getExe testEvalForge}
    declared_tools_only ${lib.getExe testWorkflowTemplates}
    declared_tools_only ${lib.getExe testCheckoutPlugins} "''${CLAUDE_CODE_PLUGIN_DIRS-}"
  '';
}
