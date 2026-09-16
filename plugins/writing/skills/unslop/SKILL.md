---
name: unslop
description: >-
  Remove AI writing patterns from prose and give it a voice. Use whenever writing or
  editing non-code text (docs, READMEs, ADRs, posts, commit messages, PR descriptions),
  before handing it over, and on request: "unslop", "humanize", "make this sound human",
  "clean up this writing", "edit for voice", "de-AI this text".
paths:
  - "**/*.md"
---

# Unslop

Edit text to remove AI patterns and add human voice.

## Process

1. Scan for the patterns below.
2. Rewrite, preserving meaning and matching the intended tone.
3. Add soul (see next section).
4. Self-audit: "What makes this obviously AI generated?" Fix remaining tells.

## Adding soul

Removing patterns is half the job.
Sterile, voiceless writing is just as obvious.

- **Have opinions.** React to facts instead of neutrally listing pros and cons.
- **Vary rhythm.** Short sentences. Then longer ones that take their time. Mix it up.
- **Acknowledge complexity.** "Impressive but also kind of unsettling" beats "impressive."
- **Use "I" when it fits.** First person isn't unprofessional.
- **Let some mess in.** Perfect structure feels algorithmic.
- **Be specific.** Not "this is concerning" but "there's something unsettling about agents churning away at 3am."

Reference documents want tight, impersonal prose: `README.md`, `CLAUDE.md`, `CONCEPTS.md`, `INTENT.md`, ADRs and API docs.
For those, apply every pattern below but skip "Use I" and "Let some mess in".

## Patterns to detect and fix

### Content

1. **Significance inflation**: "pivotal moment", "testament to", "evolving landscape", "setting the stage for", "indelible mark", "deeply rooted". Cut puffery, state what happened.
2. **Notability name-dropping**: listing media outlets without context. Pick one, say what was said.
3. **Superficial -ing phrases**: "highlighting...", "ensuring...", "reflecting...", "showcasing...", "fostering...". Delete or expand with real sources.
4. **Promotional language**: "nestled", "vibrant", "breathtaking", "groundbreaking", "renowned", "stunning", "must-visit". Use neutral descriptions.
5. **Vague attributions**: "Experts believe", "Industry reports suggest", "Some critics argue". Name the source or delete.
6. **Formulaic challenges**: "Despite challenges... continues to thrive." Replace with specific facts.

### Language

1. **AI vocabulary**: Additionally, crucial, delve, enduring, enhance, fostering, garner, interplay, intricate, landscape (abstract), pivotal, showcase, tapestry (abstract), testament, underscore, vibrant. Replace with plain words.
2. **Copula avoidance**: "serves as", "stands as", "boasts", "features". Just say "is" or "has".
3. **Negative parallelisms**: "It's not just X, it's Y." State the point directly.
4. **Rule of three**: forcing ideas into groups of three. Use the natural number.
5. **Synonym cycling**: protagonist/main character/central figure/hero in one paragraph. Pick one, repeat it.
6. **False ranges**: "from X to Y" where X and Y aren't on a meaningful scale. List topics directly.

### Style

1. **Em dash overuse**: avoid em dashes and en dashes entirely. Use periods, commas, or parentheses. Em dashes are an AI tell.
2. **Colon overuse**: colons are fine before a list or example, not as mid-sentence connectors. "If you're new to the tool: instead of editing the config by hand, you run the setup command" adds nothing with the colon. Rewrite to let the point stand on its own without comparison framing. "The setup command replaces hand-editing the config." Same meaning, no crutch punctuation.
3. **Boldface overuse**: don't bold every proper noun or acronym.
4. **Inline-header lists**: "**Performance:** Performance improved..." Convert to prose.
5. **Title case headings**: use sentence case.
6. **Decorative emojis**: remove from headings and bullets.
7. **Curly quotes**: replace with straight quotes.

### Communication artifacts

1. **Chatbot phrases**: "I hope this helps!", "Let me know if...", "Of course!", "Certainly!" Remove.
2. **Cutoff disclaimers**: "While specific details are limited..." Find sources or remove.
3. **Sycophantic tone**: "Great question! You're absolutely right!" Respond directly.

### Filler

1. **Filler phrases**: "In order to" → "To". "Due to the fact that" → "Because". "It is important to note that" → delete.
2. **Excessive hedging**: "could potentially possibly be argued that it might" → "may".
3. **Generic conclusions**: "The future looks bright." State specific plans or facts.
