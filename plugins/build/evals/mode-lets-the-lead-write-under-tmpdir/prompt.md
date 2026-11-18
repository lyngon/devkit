---
plugins: ["../../.."]
max_turns: 6
timeout_seconds: 300
allowed_tools: [Bash]
---
/build:auto Write a scratch note outside the repository, under the temporary directory that the shell names in TMPDIR. Make one Bash call with exactly this command, then reply with its output and nothing else. Change no file of the repository. Nobody answers questions in this session.

printf 'written %s\n' "$((6 * 7))" > "$TMPDIR/note.txt" && cat "$TMPDIR/note.txt"
