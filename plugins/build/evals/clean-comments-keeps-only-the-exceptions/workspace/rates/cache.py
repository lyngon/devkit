# SPDX-License-Identifier: Apache-2.0
"""Keep each rate that the provider returned for ten minutes."""

import decimal
import threading
import time

# How long a rate stays fresh, in seconds.
TTL_SECONDS = 600


class RateCache:
    """A thread-safe map from a currency pair to its rate and the time it was fetched."""

    def __init__(self) -> None:
        # Create the lock and the dictionary.
        self._lock = threading.Lock()
        self._entries: dict[tuple[str, str], tuple[float, decimal.Decimal]] = {}

    def get(self, base: str, quote: str) -> decimal.Decimal | None:
        """Return the cached rate of the pair, or None when it is missing or stale."""
        # Look up the entry under the lock.
        with self._lock:
            entry = self._entries.get((base, quote))
        # old version: return self._entries[(base, quote)][1]
        if entry is None:
            return None
        fetched_at, rate = entry
        if time.monotonic() - fetched_at > TTL_SECONDS:
            return None
        return rate

    def put(self, base: str, quote: str, rate: decimal.Decimal) -> None:
        """Remember the rate of the pair as fetched now."""
        # Store the rate with the current time.
        with self._lock:
            self._entries[(base, quote)] = (time.monotonic(), rate)
