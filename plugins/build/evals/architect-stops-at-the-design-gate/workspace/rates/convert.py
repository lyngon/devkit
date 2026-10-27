"""Convert an amount from one currency to another."""

import decimal

from rates import client

CENT = decimal.Decimal("0.01")


def convert(amount: decimal.Decimal, base: str, quote: str) -> decimal.Decimal:
    """Return `amount` in `base` as an amount in `quote`, rounded to cents."""
    if base == quote:
        return amount
    rate = client.fetch_rate(base, quote)
    return (amount * rate).quantize(CENT, rounding=decimal.ROUND_HALF_EVEN)
