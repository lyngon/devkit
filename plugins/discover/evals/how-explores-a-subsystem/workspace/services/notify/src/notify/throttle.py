"""Keeps a recipient from getting message after message about one parcel."""

import datetime as dt

MIN_GAP: dt.timedelta = dt.timedelta(minutes=45)


class Throttle:
    """Remembers when the recipient of each parcel was last messaged."""

    def __init__(self) -> None:
        self._last: dict[str, dt.datetime] = {}

    def allows(self, parcel_id: str, now: dt.datetime) -> bool:
        """False while the last message about the parcel is younger than MIN_GAP."""
        last = self._last.get(parcel_id)
        return last is None or now - last >= MIN_GAP

    def record(self, parcel_id: str, now: dt.datetime) -> None:
        """Note that a message about the parcel was handed to the gateway at `now`."""
        self._last[parcel_id] = now
