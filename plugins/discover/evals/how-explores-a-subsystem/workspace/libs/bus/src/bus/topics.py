"""The topics of the parcel flow, and the port a service sends through."""

import typing as t

from bus import envelope

SCANNED: str = "parcel.scanned"
STATUS_CHANGED: str = "parcel.status-changed"


class Publisher(t.Protocol):
    """What a service needs from the bus to send."""

    def publish(self, message: envelope.Envelope) -> None:
        """Hand the message to the bus. Raises ConnectionError when the bus cannot take it."""
        ...
