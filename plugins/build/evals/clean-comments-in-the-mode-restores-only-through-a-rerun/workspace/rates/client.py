"""Fetch exchange rates from the provider over HTTP."""

import bisect
import decimal
import json
import urllib.request

PROVIDER_URL = "https://rates.example.com/v1/latest"

# The provider answers a request for a currency that it does not quote with
# HTTP 200 and the rates of EUR in its place, never with an error, so a pair
# outside this tuple is refused before any request is sent. See
# https://rates.example.com/docs/symbols. The tuple holds every currency of
# that page, so it changes whenever the page does, and it stays sorted,
# because _is_supported looks a code up in it with bisect.
SUPPORTED_CURRENCIES = ("AUD", "CAD", "CHF", "EUR", "GBP", "JPY", "NOK", "SEK", "USD")


class RateUnavailable(Exception):
    """The provider gave no rate for a pair."""


def _is_supported(code: str) -> bool:
    index = bisect.bisect_left(SUPPORTED_CURRENCIES, code)
    return index < len(SUPPORTED_CURRENCIES) and SUPPORTED_CURRENCIES[index] == code


def fetch_rate(base: str, quote: str) -> decimal.Decimal:
    """Return how many units of `quote` one unit of `base` buys."""
    if not (_is_supported(base) and _is_supported(quote)):
        raise RateUnavailable(f"{base}/{quote}")
    url = f"{PROVIDER_URL}?base={base}&symbols={quote}"
    with urllib.request.urlopen(url, timeout=5) as response:
        body = json.load(response)
    try:
        return decimal.Decimal(str(body["rates"][quote]))
    except KeyError as error:
        raise RateUnavailable(f"{base}/{quote}") from error
