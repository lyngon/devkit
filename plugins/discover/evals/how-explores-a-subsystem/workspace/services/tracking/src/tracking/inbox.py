"""Reads scans off the bus."""

import dataclasses
import datetime as dt
import json

from bus import envelope


class MalformedScan(Exception):
    """A message on the scan topic whose body is not a scan."""


@dataclasses.dataclass(frozen=True, slots=True)
class ScanEvent:
    """A scan as this service knows it. The checkpoint stays a string, so that a new one needs no release here."""

    parcel_id: str
    sequence: int
    checkpoint: str
    scanned_at: dt.datetime


def decode(message: envelope.Envelope) -> ScanEvent:
    """The scan a message carries. Raises MalformedScan for a body that lacks a field or holds a wrong value."""
    try:
        fields = json.loads(message.body)
        return ScanEvent(
            parcel_id=str(fields["parcel"]),
            sequence=int(fields["sequence"]),
            checkpoint=str(fields["checkpoint"]),
            scanned_at=dt.datetime.fromisoformat(str(fields["at"])),
        )
    except (KeyError, TypeError, ValueError) as error:
        raise MalformedScan(message.key) from error
