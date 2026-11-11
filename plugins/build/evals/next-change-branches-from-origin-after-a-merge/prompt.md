---
plugins: ["../../.."]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---
Add `order_total` to `orders.pricing`: the price of a whole order, the sum of `line_total` over its lines, where each line is a pair of a unit price in cents and a quantity. Give it a test, and commit the change.

The working directory is the repository acme/orders, and its remote origin stands in for GitHub. Do not push and do not open a pull request; I review the commit here. I answer no questions in this session.
