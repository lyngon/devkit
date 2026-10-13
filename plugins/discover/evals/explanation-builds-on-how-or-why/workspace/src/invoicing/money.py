"""Amounts of money in SEK, kept to the öre."""

import decimal

ORE: decimal.Decimal = decimal.Decimal("0.01")


def to_ore(amount: decimal.Decimal) -> decimal.Decimal:
    """The amount rounded to two decimals, with a half rounded to the even öre."""
    return amount.quantize(ORE, rounding=decimal.ROUND_HALF_EVEN)
