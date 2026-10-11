# Code archaeology (git + in-repo)

## What this source contains

- Commit history (messages, dates, authors, diffs)
- PR descriptions, review comments, and discussion threads (via `gh`)
- Inline code comments, TODOs, FIXMEs, deprecation notes
- Decision records in `docs/decisions/`, at the root or inside a package, and in git the ones that were deleted when their decision changed
- Tests. Names and assertions often encode the edge cases that motivated a change
- Related files modified in the same commits (co-change signal)
- CHANGELOG entries, release notes in the repo
- Issue/ticket IDs mentioned in commit messages and PR bodies

The most trustworthy source, tied directly to the code, and the most complete.
Everything that went through the repo should be here.

## How to search it

Read the decision records first.
A record that names the target states the decision and its reason in the author's words, and a deleted record says what was decided before:

```bash
# Decision records that mention the target
git grep -n -i -e '<symbol_or_term>' -- ':(top,glob)**/docs/decisions/**'

# Records that were deleted, with the commit that deleted each.
# docs/adr/ is where records lived before they were named after their decision.
# --no-renames, or git pairs a deleted record with the one that replaced it and lists neither
git log --no-renames --diff-filter=D --name-only --format='%h %ad %s' --date=short -- ':(top,glob)**/docs/decisions/**' ':(top,glob)**/docs/adr/**'

# The text of a deleted record, from the parent of the commit that deleted it
git show <hash>^:<path>
```

A record is deleted when its decision changes or when a check comes to carry it.
The commit that deleted it, and its PR, say which.

Then expand the seed commit list:

```bash
# Full history of the file through renames
git log --follow --oneline -- <file>

# Pickaxe: commits that added or removed this exact text
git log -S '<exact_string_from_code>' -- <file>

# Or for patterns:
git log -G '<regex>' -- <file>

# Who wrote each line and when
git blame -L <start>,<end> <file>

# The full diff of a specific commit
git show <hash>

# Commits between two points affecting this file
git log <old>..<new> -p -- <file>
```

For each substantive commit, pull the PR context:

```bash
# Find the PR number from the merge commit or branch
git log -1 --format=%B <hash>

# Or ask the forge which merged PR holds the commit
gh pr list --state merged --search <hash> --json number,title

# Full PR context: body, review comments, linked issues
gh pr view <number> --json title,body,author,createdAt,mergedAt,labels,closingIssuesReferences,comments,reviews,files

# The --json reviews and comments fields are where the real signal is
```

Look for what the tree itself says:

```bash
# TODOs and FIXMEs near the target
git grep -n -C2 -E '(TODO|FIXME|HACK|XXX|NOTE)' -- <target_file>

# Related tests. Names often encode the "why"
git grep -l '<symbol>' -- '*test*'
```

## What good evidence looks like here

- A decision record whose title is the decision in question, or a deleted one with the commit that replaced it
- A PR description that explains the problem being solved, not just the change ("This fixes the pagination bug that caused X")
- A long review thread where alternatives were debated
- An inline comment near the target line that explains a non-obvious constraint
- A test named `test_handles_edge_case_when_X` that reveals an edge case motivating the code
- A commit message that references a ticket or incident ID
- A CHANGELOG entry that summarizes the user-visible rationale

## Common pitfalls

- **Squash-merge flatlands.** If the repo squashes PRs, individual commits in the branch history are lost. Fall back to PR body and comments.
- **Misleading commit messages.** "Small refactor" sometimes hides an intentional behavior change. Look at the diff, not the message.
- **Cargo-culted patterns.** The author may have copied a pattern without understanding why. Check if the pattern originated earlier in the codebase and investigate *that* commit.
- **Bot commits and auto-merges.** Dependabot, Renovate, and automated backports usually don't carry motivation. Skip them when trying to find intent.
- **Reading an old record as current.** A deleted decision record says what held then. Check what replaced it before citing it for the present.
- **`gh` out of reach.** If `gh` is missing, not signed in or refused, the PR bodies and reviews are a gap. Report the error, and never report that the PRs said nothing.
- **Treating code as evidence of intent.** The code itself isn't evidence for why it exists. Evidence comes from commit messages, PRs, comments, tests, docs. Don't cite "the function is named X" as evidence of intent.

## What to return

Every decision record, commit, PR and comment that bears on the question, with:

- The exact text (quoted)
- The record's path (and the commit that deleted it) / hash / PR number / file:line
- Author and date
- Whether it's direct (explicitly addresses the question) or circumstantial
