"""The prices of the lines of an order, in cents."""

BULK_QUANTITY = 10
BULK_DISCOUNT_PERCENT = 10


def line_total(unit_price_cents: int, quantity: int) -> int:
    """The price of a line: the unit price times the quantity, less the bulk discount on a large line."""
    total = unit_price_cents * quantity
    if quantity > BULK_QUANTITY:
        total -= total * BULK_DISCOUNT_PERCENT // 100
    return total
