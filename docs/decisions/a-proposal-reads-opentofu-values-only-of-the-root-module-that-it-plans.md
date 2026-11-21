# A proposal reads OpenTofu values only of the root module that it plans

The tool of `build:live-mutation` hides only the values that the frozen plan of its OpenTofu form marks sensitive, so it refuses every command of a proposal that could print values of any other plan or state.
The generic form refuses a proposal whose frozen inputs hold an OpenTofu saved plan, and any command that runs an OpenTofu command that prints values, such as `plan`, `show`, `output`, `state show` or `console`.
The OpenTofu form refuses a check or a demonstration that runs one against a root module other than its own.
A command that names `tofu` and that the tool cannot read, such as through a wrapper, a script or a variable, is refused as the plugin's OpenTofu hook refuses one, by the same reader.
A check of another root module stays a read in the shell, outside the proposal, and a refactor across root modules goes through `moved`, `removed` and `import` blocks in the OpenTofu form.

## Considered options

- The skill tells the agent to keep such commands out of a proposal, and nothing refuses one. The agent's judgment alone then keeps every such value out of the action record, and nothing fails when it errs.
- The tool detects a saved plan among the generic form's frozen inputs, and nothing more. A plan that a check runs prints its values all the same.
- Each check names the root module it reads, and the tool learns that root module's sensitive values as it learns the OpenTofu form's. That would build on this refusal, and it waits until a check needs it.

Enforced by: `plugins/build/tests/live-mutation.sh`
