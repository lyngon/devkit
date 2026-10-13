# The Lyngon baseline for every repository: git hooks, the devenv MCP server
# file, the check-pull-request command, the tools of the scripts that skills
# ship, and the languages every Lyngon repository has (Nix, shell).
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
  pkgs,
  ...
}:
let
  cfg = config.lyngon;

  # The devenv root as a path from the root of the working tree, "." where
  # the two are one directory. Null outside a git repository, and where
  # devenv reached its root through a path that git does not report.
  rootInWorkingTree =
    if config.git.root == null then
      null
    else if config.devenv.root == config.git.root then
      "."
    else if lib.hasPrefix "${config.git.root}/" config.devenv.root then
      lib.removePrefix "${config.git.root}/" config.devenv.root
    else
      null;

  # The hook types that the hook configuration installs no shim for. A stage
  # may carry the old name of its type, without the "pre-".
  unusedHookTypes =
    lib.subtractLists
      (map (
        stage:
        if
          lib.elem stage [
            "commit"
            "merge-commit"
            "push"
          ]
        then
          "pre-${stage}"
        else
          stage
      ) config.git-hooks.installStages)
      [
        "commit-msg"
        "post-checkout"
        "post-commit"
        "post-merge"
        "post-rewrite"
        "pre-commit"
        "pre-merge-commit"
        "pre-push"
        "pre-rebase"
        "prepare-commit-msg"
      ];

  # Writes the shim of each of those types again, with the path of the hook
  # configuration from the root of the working tree. Only a shim that the
  # hook tool generated: its uninstall leaves a hook written by hand in
  # place, and then nothing is installed over it.
  refreshUnusedHookShims = pkgs.writeShellApplication {
    name = "refresh-unused-hook-shims";
    runtimeInputs = [ pkgs.git ];
    text = ''
      # The hook tool reports what it skips and what it writes, which is
      # worth reading only when it fails.
      quietly() {
        local output
        if ! output=$("$@" 2>&1); then
          echo "$output" >&2
          return 1
        fi
      }

      hooks=$(git rev-parse --path-format=absolute --git-path hooks)
      for type in ${lib.concatStringsSep " " unusedHookTypes}; do
        [[ -e "$hooks/$type" ]] || continue
        quietly ${lib.getExe config.git-hooks.package} uninstall -t "$type"
        [[ ! -e "$hooks/$type" ]] || continue
        quietly ${lib.getExe config.git-hooks.package} install -c "$DEVENV_ROOT/${config.git-hooks.configPath}" -t "$type"
      done
    '';
  };

  # Em and en dashes and curly quotes, in Markdown as a hook and in the title
  # and the body of a pull request through check-pull-request. The
  # deterministic half of prose quality; the judgment half is the writing
  # plugin's unslop skill.
  proseLint = pkgs.writeShellApplication {
    name = "prose-lint";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = builtins.readFile ./prose-lint.sh;
  };

  # The layout rules of shared/STRUCTURE.md section 4.4: dependency direction
  # between apps, libs, contracts, tools and infra, explicit workspace member
  # lists, package documents, and no language names as path segments.
  validateStructure = pkgs.writeShellApplication {
    name = "validate-structure";
    runtimeInputs = [
      pkgs.python3
      pkgs.git
    ];
    text = ''exec python3 ${./validate-structure.py} "$@"'';
  };

  # The document rules: an agent file that imports INTENT.md, no AGENTS.md, no
  # CLAUDE.md outside .claude/, no docs/adr/, and the shape of decision
  # records, INTENT.md, rule files and the files of the mistake ledger.
  validateDocuments = pkgs.writeShellApplication {
    name = "validate-documents";
    runtimeInputs = [
      pkgs.python3
      pkgs.git
    ];
    text = ''exec python3 ${./validate-documents.py} "$@"'';
  };

  # Checks the title and the body of a pull request: a Conventional Commits
  # title, the seven headings of the body, its length and the marks prose-lint
  # flags. A pull request lands as one commit with the two as its message, so
  # the baseline has no hook on the message of a commit on a branch. The two
  # length values are written into the command, so a local shell and CI check
  # against the same numbers, and it takes no arguments, so neither can be
  # raised from outside.
  checkPullRequest = pkgs.writeShellApplication {
    name = "check-pull-request";
    runtimeInputs = [
      pkgs.python3
      pkgs.commitizen
      proseLint
    ];
    text = ''
      if (($# > 0)); then
        echo "check-pull-request: takes no arguments; it reads the title from PR_TITLE and the body from PR_BODY" >&2
        exit 2
      fi
      exec python3 ${./check-pull-request.py} \
        --target-lines ${toString cfg.pullRequest.body.targetLines} \
        --headroom-lines ${toString cfg.pullRequest.body.headroomLines}
    '';
  };
in
{
  options.lyngon = {
    enable = lib.mkEnableOption "the Lyngon baseline";

    mcp.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate .mcp.json with the devenv MCP server for Claude Code.";
    };

    structure.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "The repository follows the Lyngon structure (shared/STRUCTURE.md); enables the validate-structure hook.";
    };

    pullRequest.body = {
      targetLines = lib.mkOption {
        type = lib.types.ints.positive;
        default = 40;
        description = "Content lines of a pull request body above which check-pull-request warns. A content line is neither blank nor one of the seven headings.";
      };

      headroomLines = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 20;
        description = "Content lines above the target that a pull request body may have before check-pull-request fails. The limit is the target plus the headroom; with 0 the target is the limit.";
      };
    };

    mistakes.maxAgeDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 365;
      description = "Days a file of the mistake ledger, docs/mistakes/, is kept after its date. The correction skill of the build plugin deletes an older file, and reads the limit from LYNGON_MISTAKES_MAX_AGE_DAYS.";
    };

    scriptTools = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ pkgs.python3 ];
      defaultText = lib.literalExpression "[ pkgs.python3 ]";
      description = "The tools a script that a skill ships may run, added to the shell. Such a script takes nothing else from the PATH. A value set here replaces the default, so keep pkgs.python3 in it.";
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

    # On the PATH of the shell, so a person, an agent and CI run the same
    # check. A script and not an entry in `packages`: a default list there is
    # dropped as soon as a repository lists a package of its own.
    scripts.check-pull-request = {
      exec = lib.mkDefault ''exec ${lib.getExe checkPullRequest} "$@"'';
      description = lib.mkDefault "Check PR_TITLE and PR_BODY as the commit a pull request lands as.";
    };

    # What a script that a skill ships runs, on the PATH of the shell an agent
    # works in. Not a `lib.mkDefault`: a default list here is dropped as soon
    # as a repository lists a package of its own, and the list has its own
    # option to override. At low priority, so that a repository's own package
    # keeps a name both provide, such as `python3`.
    packages = map lib.lowPrio cfg.scriptTools;

    # A shipped script cannot read an option, so the limit reaches the
    # correction skill's prune-mistakes.py through the environment.
    env.LYNGON_MISTAKES_MAX_AGE_DAYS = lib.mkDefault (toString cfg.mistakes.maxAgeDays);

    # All worktrees of a clone share one hooks directory, and devenv writes
    # the absolute path of a checkout's hook configuration into the shims
    # there, so a commit in any worktree ran the hooks of whichever checkout
    # entered devenv last. Git runs a hook from the root of the working tree,
    # so a path from that root names the configuration of the checkout a
    # commit is made in, and none in a worktree that never entered devenv,
    # where the commit then fails. The install task builds the path on
    # DEVENV_ROOT and has no option for it.
    tasks."devenv:git-hooks:install" = lib.mkIf (config.git-hooks.enable && rootInWorkingTree != null) {
      cwd = lib.mkDefault config.git.root;
      env.DEVENV_ROOT = lib.mkDefault rootInWorkingTree;
    };

    # The install task writes the shims of the hook types the configuration
    # uses and touches no other, so a shim outlives its type's last use. One
    # from before the path above still names the checkout that wrote it:
    # every commit in the clone runs that checkout's configuration, and fails
    # once the configuration is gone. Such a shim gets the path from the root
    # too. It is not removed, as the installer of git-hooks.nix would,
    # because another worktree of the clone may use its type.
    tasks."lyngon:git-hooks:refresh-unused-shims" =
      lib.mkIf (config.git-hooks.enable && rootInWorkingTree != null)
        {
          after = lib.mkDefault [ "devenv:git-hooks:install" ];
          before = lib.mkDefault [ "devenv:enterShell" ];
          cwd = lib.mkDefault config.git.root;
          env.DEVENV_ROOT = lib.mkDefault rootInWorkingTree;
          exec = lib.mkDefault (lib.getExe refreshUnusedHookShims);
        };

    git-hooks.hooks = {
      nixfmt.enable = lib.mkDefault true;
      shellcheck.enable = lib.mkDefault true;
      markdownlint = {
        enable = lib.mkDefault true;
        # The agent file opens with the import of INTENT.md, not with a heading.
        excludes = lib.mkDefault [ "^\\.claude/CLAUDE\\.md$" ];
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
      prose-lint = {
        enable = lib.mkDefault true;
        name = lib.mkDefault "prose lint";
        entry = lib.mkDefault (lib.getExe proseLint);
        files = lib.mkDefault "\\.md$";
      };
      validate-documents = {
        enable = lib.mkDefault true;
        name = lib.mkDefault "validate documents";
        entry = lib.mkDefault (lib.getExe validateDocuments);
        # Every tracked path, symbolic links included: a hook sees only
        # regular files by default, and an AGENTS.md is usually a link.
        types = lib.mkDefault [ ];
        # One run over all files, so a docs/adr/ directory is reported once.
        require_serial = lib.mkDefault true;
        # Also on a commit that only deletes files: a deleted agent file is
        # never among the names a hook is handed.
        always_run = lib.mkDefault true;
      };
      validate-structure = {
        enable = lib.mkDefault cfg.structure.enable;
        name = lib.mkDefault "validate structure";
        entry = lib.mkDefault (lib.getExe validateStructure);
        # Package directories and the root workspace files.
        files = lib.mkDefault "^((apps|libs|contracts|tools|infra)/|(pyproject\\.toml|pnpm-workspace\\.yaml|Cargo\\.toml|go\\.work|package\\.json)$)";
        pass_filenames = lib.mkDefault false;
      };
      actionlint.enable = lib.mkDefault true;
      yamllint = {
        enable = lib.mkDefault true;
        settings.preset = lib.mkDefault "relaxed";
      };
    };
  };
}
