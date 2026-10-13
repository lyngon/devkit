"""An invoice and the amounts printed on it."""

import dataclasses
import decimal

from invoicing import money


@dataclasses.dataclass(frozen=True, slots=True)
class Line:
    """One row of an invoice: a quantity of one article at a unit price, with its VAT rate."""

    article: str
    quantity: decimal.Decimal
    unit_price: decimal.Decimal
    vat_rate: decimal.Decimal

    def net(self) -> decimal.Decimal:
        """The amount of the row before VAT, to the öre."""
        return money.to_ore(self.quantity * self.unit_price)

    def vat(self) -> decimal.Decimal:
        """The VAT of the row, to the öre, computed from the rounded net amount."""
        return money.to_ore(self.net() * self.vat_rate)


@dataclasses.dataclass(frozen=True, slots=True)
class Invoice:
    """The rows sent to one customer. Every total is a sum of amounts the rows already rounded."""

    number: str
    lines: tuple[Line, ...]

    def net_total(self) -> decimal.Decimal:
        """The sum of the rows before VAT."""
        return sum((line.net() for line in self.lines), decimal.Decimal(0))

    def vat_total(self) -> decimal.Decimal:
        """The sum of the VAT of the rows. Not the VAT of the net total, which can differ by an öre for each row."""
        return sum((line.vat() for line in self.lines), decimal.Decimal(0))

    def total(self) -> decimal.Decimal:
        """What the customer pays."""
        return self.net_total() + self.vat_total()
