# review

Code review, both ways.

## Skills

- `/review:request`: dispatch a fresh reviewer subagent with a crafted brief, a commit range and the plan or requirements, and act on its findings by severity. Used by the `build` executors after every task and on the whole branch, and before every pull request in the bounded and architectural flows; also on request.
- `review:receive`: evaluate review feedback technically before acting on it: restate, verify against the code, push back with reasons where wrong, implement one item at a time, and never agree performatively. The agent invokes it whenever feedback arrives.

Both are vendored from [obra/superpowers](https://github.com/obra/superpowers) (MIT).
The license is `LICENSE-superpowers` in this plugin, and the provenance record is [catalog/vendored/superpowers.md](../../catalog/vendored/superpowers.md).

## Install

Part of the `all` bundle.
On its own:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install review@lyngon --scope project
```
