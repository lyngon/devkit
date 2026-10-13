"""Where a handheld's upload enters the system."""

import collections.abc as ct

from intake import outbox, scan


class UnknownScanner(Exception):
    """A scan came from a handheld that is not registered."""


class Intake:
    """Accepts scans from handhelds. When `accept` returns, the scan is in the outbox or was a repeat."""

    def __init__(self, scanners: ct.Collection[str], pending: outbox.Outbox) -> None:
        self._scanners: ct.Collection[str] = scanners
        self._pending: outbox.Outbox = pending

    def accept(self, reading: scan.Scan) -> bool:
        """Queue the scan for the bus.

        False for a repeat, which a handheld sends when it uploads a whole batch again after a cut connection.
        Raises UnknownScanner for a handheld that is not registered.
        """
        if reading.scanner_id not in self._scanners:
            raise UnknownScanner(reading.scanner_id)
        return self._pending.add(reading)
