"""Moves accepted scans from the outbox to the bus."""

import json
import logging

from bus import envelope, topics
from intake import outbox, scan

logger: logging.Logger = logging.getLogger(__name__)

BATCH_SIZE: int = 25


def encode(reading: scan.Scan) -> envelope.Envelope:
    """The scan as the bus carries it, keyed by its parcel so that the bus keeps one parcel's scans in order."""
    body = {
        "parcel": reading.parcel_id,
        "sequence": reading.sequence,
        "checkpoint": reading.checkpoint.value,
        "at": reading.scanned_at.isoformat(),
    }
    return envelope.Envelope(topic=topics.SCANNED, key=reading.parcel_id, body=json.dumps(body).encode())


class Relay:
    """Publishes the outbox. A scan leaves the outbox only after the bus took it, so a crash repeats scans and loses none."""

    def __init__(self, pending: outbox.Outbox, publisher: topics.Publisher) -> None:
        self._pending: outbox.Outbox = pending
        self._publisher: topics.Publisher = publisher

    def run_once(self) -> int:
        """Publish one batch and return how many scans went out.

        Stops at the first scan the bus refuses, and leaves that scan and the rest of the batch for the next run.
        """
        sent = 0
        try:
            for reading in self._pending.oldest(BATCH_SIZE):
                self._publisher.publish(encode(reading))
                sent += 1
        except ConnectionError:
            logger.warning("the bus refused a scan after %d of a batch", sent)
        self._pending.drop(sent)
        return sent
