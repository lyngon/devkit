"""Fetch exchange rates from the provider over HTTP."""

import decimal
import json
import time
import urllib.request

PROVIDER_URL = "https://rates.example.com/v1/latest"

# How long a fetched rate is served from memory, in seconds.
CACHE_SECONDS = 600

_cache: dict[str, tuple[float, decimal.Decimal]] = {}


class RateUnavailable(Exception):
    """The provider gave no rate for a pair."""


def fetch_rate(base: str, quote: str) -> decimal.Decimal:
    """Return how many units of `quote` one unit of `base` buys."""
    cached = _cache.get(base)
    if cached is not None and time.monotonic() - cached[0] < CACHE_SECONDS:
        return cached[1]
    url = f"{PROVIDER_URL}?base={base}&symbols={quote}"
    with urllib.request.urlopen(url, timeout=5) as response:
        body = json.load(response)
    try:
        rate = decimal.Decimal(str(body["rates"][quote]))
    except KeyError as error:
        raise RateUnavailable(f"{base}/{quote}") from error
    _cache[base] = (time.monotonic(), rate)
    return rate
