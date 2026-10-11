# index

One provenance record for the 24 principles vendored into this skill.
The 8 principles of the group steering are written by Lyngon and have no upstream.

- **Upstream**: <https://github.com/cursor/plugins>
- **Upstream path**: `pstack/skills/principle-*`, 24 skill directories of one `SKILL.md` each, and the section "Principles" of `pstack/skills/poteto-mode/SKILL.md` for the lines of the index
- **Upstream name**: `principle-<name>`, one skill per principle
- **Upstream version**: 0.15.15 (`pstack/.cursor-plugin/plugin.json`)
- **Upstream commit**: 9f451cf875ad1239912762f67741e8e5ba6ac0f1
- **Upstream license**: MIT (see [LICENSE](LICENSE))
- **Reviewed**: 2026-10-11 by Anders Åström

## Why it is here

Lyngon steers agents by named principles they apply with judgment, where it used to script their steps.
pstack states 24 such principles in a form short enough to read whenever one applies (a statement, why, a pattern and a test), and they are the ones the owner chose to build on.
Upstream ships each principle as a skill of its own and indexes them inside its mode skill.
Here they are one skill, so that an agent reads one index and then only the files it needs.

## Local patches

All 24 files:

- Each skill `principle-<name>` became the file `references/<name>.md` of this one skill. The prefix `principle-` is dropped.
- The frontmatter (name, description, `disable-model-invocation: true`) is removed. What the description said about when the principle applies is in the principle's line of the index.
- A link to another principle points at its sibling file and uses the principle's name as the link text, where upstream linked `../principle-<name>/SKILL.md` under the principle's title.
- The heading is in sentence case.
- Paragraphs are reflowed to one sentence per line, and lists are surrounded by blank lines.

Single files:

- `never-block-on-the-human`: "the human" became the owner (who supervises and corrects) and the operator (who is the bottleneck of a pause). The section "Boundaries", with its three bullets on irreversible actions, reversible actions and product direction, is replaced by "The gate": ask only before an irreversible action or for a product or preference call that no run can settle, product direction is the owner's, and the list of actions that always need asking. The name keeps "the-human".
- `encode-lessons-in-structure`: the route "One-off -> brain note. Recurring fix -> skill or lint rule. Systemic issue -> principle." became: a first occurrence is noted in the pull request, a repeat gets the strongest check that works, and a repeat that no tool can decide becomes a principle, which in a repository is a file under `.claude/rules/`. Step 3 of the pattern follows it: "make the instruction more prominent and add an example of the failure mode" became "make it a principle and name the failure it prevents". Added the sentence "A rule without a check is debt." to the corollary. "Apply now or create a concrete todo" became "Apply now, or file an issue with the evidence", because an agent does not defer work into a file on its own. "When the human intervenes" became "When the owner or the operator intervenes", and "a brain note" in the anti-patterns became "a note".
- `outcome-oriented-execution`: added the guardrail "Keep breakage inside a branch: the default branch and every pull request head pass the full check".
- `sequence-verifiable-units`: in "Delivery", "Stack commits and PRs in the order that proves the work" became "The change, one concern delivered as one pull request, is the unit that lands. Inside it, commits may tell the story: stack them in the order that proves the work." The sentence "Each commit lands on its own and the sequence reads as an argument" became "The sequence reads as an argument." The two references in the form "the **name** principle skill" became links to the sibling files. In "Execution", "Rebase onto clean trunk first" became "Start from the up-to-date default branch", because a rebase of a pushed branch needs a force-push, which the gate asks about first.
- `explain-the-number`: the sentence "For a performance number, run the full procedure with the benchmark-checklist skill." is left out, because that skill is not in the devkit.
- `prove-it-works`: "Keep the artifact visible for the human" became "for the owner", and the parenthesis "(the **show-me-your-work** skill)" is left out, because that skill is not in the devkit.
- `type-system-discipline`: the sentence "Skills like `typescript-best-practices` ground it in specific syntax." is left out, because that skill is not in the devkit. The two references in the form "the **name** principle skill" became links to the sibling files.
- `fix-root-causes`: the bold line "Restart bugs: suspect state before code" became a heading, which markdownlint demands of a line that stands as one.

The index, `SKILL.md`:

- Its lines for the 24 principles are adapted from the section "Principles" of upstream's `poteto-mode` skill and from the descriptions of the principle skills. Each line has the form `- **<name>** (<origin>). <When it applies>. <The rule in one sentence>.`, where upstream wrote the title in bold, the skill name in parentheses and one to three sentences.
- Upstream's groups (core, architecture, verification, delegation, meta) are kept, and the group steering is added for the Lyngon principles.
- The lines of `never-block-on-the-human`, `encode-lessons-in-structure`, `outcome-oriented-execution` and `sequence-verifiable-units` state the patched rule.

## Review notes

Reviewed against `shared/SKILL-REVIEW.md` on 2026-10-11, every file read in full.

- Security: none found. The 24 files are prose, with no scripts, hooks, agents, network access, credential reads, tool permissions or encoded content, and they write nothing. `never-block-on-the-human` tells the agent to proceed without asking on reversible work; that is the behaviour wanted, and its boundary is patched to the Lyngon gate.
- Quality: every upstream description says when the principle applies. Upstream sets `disable-model-invocation: true` on each and reaches them through the inline index of its mode skill; here the index is the skill and the agent may invoke it. Trigger check: "refactor the parser so that adding a format is one file" must trigger the index, "what does this function return?" must not. Bodies are 11 to 36 lines. Three files pointed at skills that are not in the devkit (`benchmark-checklist`, `show-me-your-work`, `typescript-best-practices`); the pointers are left out.
- Fit: no em or en dashes and no curly quotes upstream. Writes no file. `encode-lessons-in-structure` routed a one-off to a "brain note", which Lyngon has no place for (patched). `sequence-verifiable-units` let each commit land on its own, where Lyngon lands one change (patched). Overlap: `prove-it-works`, `fix-root-causes` and `test-behavior-not-implementation` cover the ground of `practice:verify`, `practice:debug` and `practice:tdd`; the principles say what to judge, the skills are procedures, and both stay until the workflow is redesigned.
- License: MIT in `pstack/LICENSE`, copyright Lauren Tan. The upstream repository has no license file at its root.
- Verdict: clear with patches, all applied.
