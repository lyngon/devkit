"""Fetch exchange rates from the provider over HTTP."""

import decimal
import json
import urllib.request

from rates import cache

PROVIDER_URL = "https://rates.example.com/v1/latest"

_cache = cache.RateCache()


class RateUnavailable(Exception):
    """The provider gave no rate for a pair."""


class RateLimited(RateUnavailable):
    """The provider throttled the request."""


def fetch_rate(base: str, quote: str) -> decimal.Decimal:
    """Return how many units of `quote` one unit of `base` buys."""
    # Check the cache first.
    cached = _cache.get(base, quote)
    if cached is not None:
        return cached
    url = f"{PROVIDER_URL}?base={base}&symbols={quote}"
    with urllib.request.urlopen(url, timeout=5) as response:
        body = json.load(response)
    # The provider answers a throttled request with HTTP 200 and this body,
    # never with a 429, so the status cannot tell a throttled request apart.
    # See https://rates.example.com/docs/errors#rate-limits
    if body.get("error") == "rate_limited":
        raise RateLimited(f"{base}/{quote}")
    try:
        rate = decimal.Decimal(str(body["rates"][quote]))
    except KeyError as error:
        raise RateUnavailable(f"{base}/{quote}") from error
    # Save it in the cache.
    _cache.put(base, quote, rate)
    return rate
