# Name things

Give everything a name and refer to it by that name.
An ordered item also carries a three-digit prefix, as in `001-steering-documents`, so that it sorts in order.
Keep a bare number only where a tool assigns it.

**Why:** A positional label ("step 4", "option B", "the second rule") says nothing about what it refers to once it is quoted out of context, and it points at the wrong thing as soon as the list is reordered.
A sequence number is also shared state, and two branches both take "the next one".
A name survives reordering, can be searched for, and tells a reader what the thing is before they open it.

**Pattern:**

- Decisions, principles, rules, tasks, steps, phases, options and the questions of an interview each get a short kebab-case name that says what the thing is.
- A file is named after the thing it holds, and that name is the identifier used everywhere else.
- Items with an order (sequential tasks, steps, queued work) carry a three-digit prefix before the name. Things without an order (decision records, principles) carry the name alone.
- A number that a tool assigns and resolves, such as the number of an issue or a pull request, stays. Inside the tree, link it with its title as the link text.
- A rule's name is the identifier its check reports, so that a failure message leads to the rule.

**The test:** Quoted alone in a message next month, would the reference still say what it points at?
