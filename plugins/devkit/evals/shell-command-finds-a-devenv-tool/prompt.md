---
plugins: ["../../.."]
max_turns: 10
timeout_seconds: 300
allowed_tools: [Bash]
---
Run the command `python3 -c "import sys; print(sys.executable)" > python-of-this-run.txt` with the Bash tool in the working directory, then reply with the word "done". If the command fails, reply with its output and do nothing else.
