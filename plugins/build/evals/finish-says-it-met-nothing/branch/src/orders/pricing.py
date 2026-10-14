"""The prices of the lines of an order, in cents."""


class NegativeQuantity(ValueError):
    """A line of an order cannot hold fewer than no items."""


def line_total(unit_price_cents: int, quantity: int) -> int:
    """The price of a line: the unit price times the quantity, which may not be negative."""
    if quantity < 0:
        raise NegativeQuantity(quantity)
    return unit_price_cents * quantity
