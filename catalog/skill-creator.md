# skill-creator

- **Upstream**: <https://github.com/anthropics/claude-plugins-official>
- **Upstream commit**: 76c85b7366c8be78ce3ac67dd21945b3960d1a8c
- **Upstream path**: `plugins/skill-creator`
- **Upstream license**: Apache-2.0 (repository `LICENSE` and `skills/skill-creator/LICENSE.txt`)
- **Reviewed**: 2026-09-16 by Anders Åström
- **Skills reviewed**:
  - `skill-creator` (`skills/skill-creator/SKILL.md`, 485 lines)
  - agents: `agents/analyzer.md`, `agents/comparator.md`, `agents/grader.md`
  - scripts: `scripts/run_eval.py`, `scripts/run_loop.py`, `scripts/improve_description.py`, `scripts/generate_report.py`, `scripts/aggregate_benchmark.py`, `scripts/package_skill.py`, `scripts/quick_validate.py`, `scripts/utils.py`
  - `eval-viewer/generate_review.py`, `eval-viewer/viewer.html`, `assets/eval_review.html`, `references/schemas.md`

## Why it is in the catalog

Anthropic's own skill authoring workflow: Create, Eval, Improve and Benchmark modes with grader, comparator and analyzer agents.
`/devkit:add-skill` hands it the design settled by `discover:approach` to draft a new in-house skill, and its eval loop is better than anything we would write ourselves.
Pinned, not vendored: it is used whole and unmodified, and Anthropic maintains it.

## Review notes

Findings against `shared/SKILL-REVIEW.md` at the pinned commit:

- **Network**: the generated HTML reports load Google Fonts (`generate_report.py`, `viewer.html`); no other outbound requests found. Scripts call `claude -p` as a subprocess, which spends tokens on the user's account.
- **Credentials**: none read directly; `claude -p` uses the user's existing Claude Code login.
- **Execution surface**: Python scripts with `subprocess` calls to `claude`; no hooks, no MCP servers, no `allowed-tools` widening in the frontmatter.
- **Instruction hijacking**: none found.
- **Obfuscation**: none; plain Python and HTML.
- **Persistence**: writes eval results under the skill or working directory; `package_skill.py` writes a `.skill` zip where asked.
- **Quality**: long `SKILL.md` (485 lines) with Claude.ai and Cowork specific sections that do not apply in Claude Code; scripts need Python 3 and PyYAML, which Lyngon devenvs do not ship by default. Run them with `nix shell nixpkgs#python3 nixpkgs#python3Packages.pyyaml`.
- **Fit**: writes skills wherever it is told; `add-skill` supplies the `plugins/<concern>/skills/<name>/` target and the house shape. It does not touch `CLAUDE.md`, `CONCEPTS.md` or settings.
- **License**: Apache-2.0.
- **Verdict**: clear.
