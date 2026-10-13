"""VAT on an invoice line, in the minor unit of the currency."""

VAT_BASIS_POINTS: int = 2500


def vat(net_minor: int) -> int:
    """The VAT on a net amount, rounded half up to a whole minor unit."""
    return (net_minor * VAT_BASIS_POINTS + 5000) // 10000
