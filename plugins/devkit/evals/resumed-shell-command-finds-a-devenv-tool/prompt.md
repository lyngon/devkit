---
plugins: ["../../.."]
max_turns: 10
timeout_seconds: 300
allowed_tools: [Bash]
env: { EVAL_PREPEND_TO_PATH: ".git/forge/bin" }
---
Run the command `{ command -v python3; printf '%s\n' "$PATH"; } > path-of-this-run.txt` with the Bash tool in the working directory, then reply with the word "done". If the command fails, reply with its output and do nothing else.
