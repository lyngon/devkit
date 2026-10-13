"""The status of a parcel, and which checkpoint moves it where."""

import collections.abc as ct
import enum


class Status(enum.Enum):
    """Where a parcel is, as its recipient is told."""

    REGISTERED = "registered"
    IN_TRANSIT = "in-transit"
    OUT_FOR_DELIVERY = "out-for-delivery"
    DELIVERED = "delivered"
    RETURNED = "returned"


# A failed delivery brings the parcel back to a depot, so out-for-delivery can fall back to in-transit.
# Delivered and returned have no entry: nothing moves a parcel out of them.
_MOVES: ct.Mapping[tuple[Status, str], Status] = {
    (Status.REGISTERED, "departed-depot"): Status.IN_TRANSIT,
    (Status.IN_TRANSIT, "on-vehicle"): Status.OUT_FOR_DELIVERY,
    (Status.OUT_FOR_DELIVERY, "handed-over"): Status.DELIVERED,
    (Status.OUT_FOR_DELIVERY, "departed-depot"): Status.IN_TRANSIT,
    (Status.IN_TRANSIT, "sent-back"): Status.RETURNED,
    (Status.OUT_FOR_DELIVERY, "sent-back"): Status.RETURNED,
}


def after(current: Status, checkpoint: str) -> Status:
    """The status once the checkpoint is passed. A checkpoint that the current status has no move for leaves it as it is."""
    return _MOVES.get((current, checkpoint), current)
