import unittest

from orders import pricing


class LineTotalTest(unittest.TestCase):
    def test_line_total_is_the_unit_price_times_the_quantity(self) -> None:
        self.assertEqual(pricing.line_total(250, 3), 750)

    def test_a_large_line_gets_the_bulk_discount(self) -> None:
        self.assertEqual(pricing.line_total(100, 12), 1080)
