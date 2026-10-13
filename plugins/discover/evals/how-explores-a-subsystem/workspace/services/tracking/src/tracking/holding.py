"""The scans of one parcel that arrived ahead of their turn."""

from tracking import inbox

LIMIT: int = 16


class HoldingPen:
    """Scans that wait for an earlier one, by sequence. A scan held twice is kept once."""

    def __init__(self) -> None:
        self._held: dict[int, inbox.ScanEvent] = {}

    def __len__(self) -> int:
        return len(self._held)

    def hold(self, event: inbox.ScanEvent) -> None:
        """Keep the scan until `release` is asked for its sequence."""
        self._held[event.sequence] = event

    def release(self, sequence: int) -> inbox.ScanEvent | None:
        """Hand over the scan with this sequence and forget it. None when no such scan is held."""
        return self._held.pop(sequence, None)

    def lowest(self) -> int:
        """The smallest sequence held. Raises ValueError when the pen is empty."""
        return min(self._held)
