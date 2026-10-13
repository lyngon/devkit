# VAT is rounded on each invoice line

Computing VAT once, on the net total, is simpler and is what most invoicing code does.
We round the VAT of each line to the öre and add the rounded amounts up, because the purchasing system of Nordfrakt, our largest customer, recomputes every line and rejects an invoice whose totals differ from the sum of its lines by a single öre.
In March 2026 it rejected 41 invoices, and each one was paid about three weeks late.

## Consequences

- An invoice with many lines can show a VAT total that is a few öre off the VAT of its net total. That difference is intended.

Enforced by: judgment
