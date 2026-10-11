# Use purpose-built tools

A script or check uses the tool built for the task, such as jq for JSON, declared through Nix and pinned, and takes nothing from the ambient PATH.
Highly custom logic is a Python program shipped as source next to what uses it.

**Why:** A script written for a bare machine ends up reimplementing what a purpose-built tool already does, and that hand-rolled logic is where scripts break and what makes them hard to maintain.
The habit of assuming only standard utilities does not apply here.
Every Lyngon machine has Nix, so any tool in nixpkgs is available to a script that declares it.
A tool taken from the ambient PATH is a different version on every machine, or missing, and the script then fails where its author never ran it.

**Pattern:**

- Reach for the tool that parses the format: jq for JSON, a parser for YAML or TOML, the forge's command-line tool for the forge. No grep, sed or awk over structured data.
- Declare every tool the script runs where the repository declares its environment, so that the lock file pins it. That includes the tools that feel universal, such as grep, sed and the coreutils.
- When the logic outgrows a pipeline (state, branching on parsed data, more than a screen of shell), write a Python program, keep it as source next to the skill or check that uses it, and declare its interpreter the same way.
- Never install a tool imperatively to make a script run.

**The test:** On a machine with nothing but Nix and this repository, does the script run and give the same result?
And does any part of it do by hand what a tool already does?
