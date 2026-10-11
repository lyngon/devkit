# Reshape instead of commenting

A comment explaining a surprise in your own code is fixed in the code.

**Why:** A comment that explains a surprise admits that the code misleads its reader, and leaves it misleading.
Nothing checks the comment, so it drifts from the code it explains, and the next reader meets the surprise together with a wrong explanation of it.
Code reshaped until the surprise is gone needs no explanation and cannot drift.

**Pattern:**

- When you reach for a comment, name what would surprise the reader, then remove it: rename, extract a function whose name gives the reason, replace a flag with a type, reorder so that cause comes before effect.
- A magic value becomes a named constant, and its reason goes into the name or into a test.
- A "do not do X here" comment becomes a check, a type or a test that fails when someone does X.
- Keep a comment for what the code cannot show even after reshaping: a constraint imposed from outside (a vendor bug, a protocol quirk, a legal requirement), with a pointer to its source.
- The principle covers your own code. Code you do not own (vendored, generated, a dependency) is not reshaped, and the comment goes where you call it.

**The test:** Does this comment explain something the code could be changed to show?
Then change the code and delete the comment.
