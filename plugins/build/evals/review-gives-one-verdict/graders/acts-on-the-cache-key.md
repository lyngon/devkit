---
type: llm
focus: last_message
---
PASS if the section of the reply headed "Act on" names this defect: the cache of exchange rates is keyed by the base currency alone, without the quote currency, so a lookup of another pair with the same base currency is answered with the wrong cached rate.
FAIL if that defect is missing from the "Act on" section, whether it is absent from the reply or placed under another heading.
