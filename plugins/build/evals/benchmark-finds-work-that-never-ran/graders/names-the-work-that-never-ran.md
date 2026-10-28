---
type: llm
focus: last_message
---
PASS if the reply does not confirm that parse_lazy is faster, and says that the measurement is wrong because the rows of parse_lazy are never iterated or consumed inside the timed region, so that its work never happened.
FAIL if the reply confirms the speedup, or rejects it without saying that the rows of parse_lazy were never read.
