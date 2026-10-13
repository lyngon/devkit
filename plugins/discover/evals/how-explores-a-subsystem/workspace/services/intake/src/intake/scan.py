"""A reading of a parcel's tag, as a handheld in a depot or a vehicle reports it."""

import dataclasses
import datetime as dt
import enum


class Checkpoint(enum.Enum):
    """Where in its journey a parcel was read."""

    DEPARTED_DEPOT = "departed-depot"
    ON_VEHICLE = "on-vehicle"
    HANDED_OVER = "handed-over"
    SENT_BACK = "sent-back"


@dataclasses.dataclass(frozen=True, slots=True)
class Scan:
    """One reading. The tag counts its own readings from 1, so the sequence is right even when a handheld uploads late."""

    parcel_id: str
    sequence: int
    checkpoint: Checkpoint
    scanned_at: dt.datetime
    scanner_id: str
