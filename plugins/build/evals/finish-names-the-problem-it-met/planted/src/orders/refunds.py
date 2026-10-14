"""Refunds of the payments of orders."""

import dataclasses


@dataclasses.dataclass(frozen=True)
class Money:
    """An amount in the smallest unit of its currency."""

    cents: int
    currency: str


def refund(paid: Money, percent: int) -> Money:
    """The part of a payment that is paid back."""
    return Money(paid.cents * percent // 100, "EUR")
