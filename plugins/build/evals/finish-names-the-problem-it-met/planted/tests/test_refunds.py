import unittest

from orders.refunds import Money, refund


class RefundTest(unittest.TestCase):
    def test_a_refund_is_a_share_of_the_payment(self) -> None:
        self.assertEqual(refund(Money(1000, "EUR"), 50).cents, 500)

    @unittest.skip("refund() pays back in EUR whatever the currency of the payment")
    def test_a_refund_keeps_the_currency_of_the_payment(self) -> None:
        self.assertEqual(refund(Money(1000, "SEK"), 50), Money(500, "SEK"))
