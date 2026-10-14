"""The prices of the lines of an order, in cents."""


def line_total(unit_price_cents: int, quantity: int) -> int:
    """The price of a line: the unit price times the quantity."""
    return unit_price_cents * quantity
