# The Lyngon baseline for every repository: git hooks, the devenv MCP server
# file, the check-pull-request command, and the languages every Lyngon
# repository has (Nix, shell).
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

  # Em and en dashes and curly quotes in Markdown and commit messages. The
  # deterministic half of prose quality; the judgment half is the writing
  # plugin's unslop skill.
  proseLint = pkgs.writeShellApplication {
    name = "prose-lint";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
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
  # records, INTENT.md and rule files.
  validateDocuments = pkgs.writeShellApplication {
    name = "validate-documents";
    runtimeInputs = [
      pkgs.python3
      pkgs.git
    ];
    text = ''exec python3 ${./validate-documents.py} "$@"'';
  };

  # The title and the body of a pull request, which land as one commit: a
  # Conventional Commits title, the seven headings of the body, its length and
  # the marks prose-lint flags. The two length values are written into the
  # command, so a local shell and CI check against the same numbers, and it
  # takes no arguments, so neither can be raised from outside.
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
      commitizen.enable = lib.mkDefault true;
      prose-lint = {
        enable = lib.mkDefault true;
        name = lib.mkDefault "prose lint";
        entry = lib.mkDefault (lib.getExe proseLint);
        files = lib.mkDefault "\\.md$";
      };
      prose-lint-commit-msg = {
        enable = lib.mkDefault true;
        name = lib.mkDefault "prose lint (commit message)";
        entry = lib.mkDefault "${lib.getExe proseLint} --commit-msg";
        stages = lib.mkDefault [ "commit-msg" ];
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
