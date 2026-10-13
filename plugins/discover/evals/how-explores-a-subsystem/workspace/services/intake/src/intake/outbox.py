"""The scans that are accepted and not yet on the bus."""

import collections
import itertools

from intake import scan


class Outbox:
    """Pending scans, oldest first. A scan is identified by its parcel and its sequence."""

    def __init__(self) -> None:
        self._seen: set[tuple[str, int]] = set()
        self._pending: collections.deque[scan.Scan] = collections.deque()

    def add(self, reading: scan.Scan) -> bool:
        """Queue the scan, unless one with its parcel and sequence was queued before. True when it was queued."""
        identity = (reading.parcel_id, reading.sequence)
        if identity in self._seen:
            return False
        self._seen.add(identity)
        self._pending.append(reading)
        return True

    def oldest(self, limit: int) -> list[scan.Scan]:
        """The oldest pending scans, at most `limit` of them. They stay pending."""
        return list(itertools.islice(self._pending, limit))

    def drop(self, count: int) -> None:
        """Forget the oldest `count` scans, once the bus has them."""
        for _ in range(count):
            _ = self._pending.popleft()
