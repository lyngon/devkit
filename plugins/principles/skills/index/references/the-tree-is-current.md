# The tree is current

The tree holds what is true now.
Superseded text is deleted, and git and `discover:why` hold the past.

**Why:** An agent treats every file it opens as true.
A superseded decision, a finished plan or a note about how things used to be reads exactly like a current one, so it gets followed.
Deleting loses nothing, because git keeps every version and `discover:why` reads the reason back when someone needs it.

**Pattern:**

- When a decision changes, delete its record and write the new one in the same change. No status field, no change log, no "superseded by".
- Delete a plan, a design or a deferred item in the change that finishes its work.
- Write what is, not what changed: "X does Y", never "X now does Y" or "X no longer does Z". What changed belongs in the commit message, the pull request and the changelog.
- Remove dead code, stale comments and compatibility notes instead of marking them.
- Keep no file for history. To learn how something came to be, ask `discover:why`, which reads the decision records, git and the pull requests.

**The test:** Would an agent that read this file with no history act on anything that is no longer true?
