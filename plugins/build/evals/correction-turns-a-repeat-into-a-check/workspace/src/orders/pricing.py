"""The price of an order, in the minor unit of the currency."""

import logging

logger = logging.getLogger(__name__)


def order_total(line_totals: list[int], discount_basis_points: int) -> int:
    """The sum of the lines less the discount, rounded down to a whole minor unit."""
    gross = sum(line_totals)
    discount = gross * discount_basis_points // 10000
    logger.debug("order total %d less discount %d", gross, discount)
    return gross - discount
