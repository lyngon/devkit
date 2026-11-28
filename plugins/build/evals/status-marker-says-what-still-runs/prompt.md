---
plugins: ["../../.."]
max_turns: 20
timeout_seconds: 600
allowed_tools: [Bash]
---
Start the shell command `sleep 20` with the Bash tool in the background, with run_in_background set to true, and end your turn at once without waiting for it. When it has finished, tell me so in one line, and then nothing else is needed. The working directory is empty, and no files are involved.
