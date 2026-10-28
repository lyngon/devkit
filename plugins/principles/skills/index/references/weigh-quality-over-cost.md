# Weigh quality over cost

A decision weighs toward the quality of the result: simplicity, robustness and long-term maintainability.
The cost of building it gets little weight.

**Why:** An agent writes code fast, so what a design costs to build is the cheap part, and what it costs to live with is paid again in every later change.
A shortcut taken because it was quicker to write is read, worked around and copied by every session that meets it.
Simplicity is part of quality, so this is no license for more machinery: an abstraction or an option that no case needs costs every reader too.

**Pattern:**

- Between two designs, take the simpler, more robust and easier to maintain, also when it takes longer to build.
- Count what a design costs to read, change and run, not what it costs to write.
- Build no speculative abstraction, and no configuration for a case nobody has.
- When a design is cheaper to build and worse to keep, the cheapness is no argument for it.

**The test:** Would you choose the same design if both took the same effort to build?
If not, the effort decided, and it should not have.
