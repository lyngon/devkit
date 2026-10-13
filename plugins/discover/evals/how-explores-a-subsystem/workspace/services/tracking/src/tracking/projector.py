"""Folds the scans of each parcel into its status."""

import dataclasses
import json
import logging

from bus import envelope, topics
from tracking import holding, inbox, status

logger: logging.Logger = logging.getLogger(__name__)


@dataclasses.dataclass(slots=True)
class _Parcel:
    status: status.Status = status.Status.REGISTERED
    next_sequence: int = 1
    pen: holding.HoldingPen = dataclasses.field(default_factory=holding.HoldingPen)


class Projector:
    """Applies the scans of a parcel strictly in the order of their sequence, and announces each change of status."""

    def __init__(self, publisher: topics.Publisher) -> None:
        self._publisher: topics.Publisher = publisher
        self._parcels: dict[str, _Parcel] = {}

    def on_scan(self, message: envelope.Envelope) -> None:
        """Take one message of the scan topic.

        A scan whose turn has passed is a repeat and is dropped.
        Every other scan goes into the parcel's pen, and the pen is drained for as long as the next scan in turn is there.
        Raises inbox.MalformedScan for a message that is not a scan.
        """
        event = inbox.decode(message)
        parcel = self._parcels.setdefault(event.parcel_id, _Parcel())
        if event.sequence < parcel.next_sequence:
            return
        parcel.pen.hold(event)
        if event.sequence > parcel.next_sequence and len(parcel.pen) > holding.LIMIT:
            # A scan that never arrives must not stall its parcel for good, so the gap is given up on.
            skipped_to = parcel.pen.lowest()
            logger.warning("parcel %s: gave up on the scans %d to %d", event.parcel_id, parcel.next_sequence, skipped_to - 1)
            parcel.next_sequence = skipped_to
        self._drain(parcel)

    def _drain(self, parcel: _Parcel) -> None:
        while (event := parcel.pen.release(parcel.next_sequence)) is not None:
            self._apply(parcel, event)
            parcel.next_sequence = event.sequence + 1

    def _apply(self, parcel: _Parcel, event: inbox.ScanEvent) -> None:
        changed = status.after(parcel.status, event.checkpoint)
        if changed is parcel.status:
            return
        parcel.status = changed
        body = {"parcel": event.parcel_id, "status": changed.value, "at": event.scanned_at.isoformat()}
        self._publisher.publish(
            envelope.Envelope(topic=topics.STATUS_CHANGED, key=event.parcel_id, body=json.dumps(body).encode())
        )
