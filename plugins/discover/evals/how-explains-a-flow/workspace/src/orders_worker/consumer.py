"""Takes jobs off the queue and runs their handler."""

import collections.abc as ct
import dataclasses
import logging
import typing as t

from orders_worker import job, parking, retry

logger: logging.Logger = logging.getLogger(__name__)


class Queue(t.Protocol):
    """The queue a consumer reads from and writes back to."""

    def put(self, queued: job.Job, delay_seconds: int) -> None:
        """Make the job visible to consumers once the delay has passed."""
        ...


class Consumer:
    """Runs one job at a time and settles every failure, so a handler never sees a retry."""

    def __init__(self, queue: Queue, lot: parking.ParkingLot, handler: ct.Callable[[bytes], None]) -> None:
        self._queue: Queue = queue
        self._lot: parking.ParkingLot = lot
        self._handler: ct.Callable[[bytes], None] = handler

    def handle(self, received: job.Job) -> None:
        """Run the handler on the job. A failure never propagates: the job is requeued or parked."""
        try:
            self._handler(received.payload)
        except Exception as error:  # noqa: BLE001  # every failure of a handler is settled here
            self._settle(dataclasses.replace(received, attempts=received.attempts + 1), error)

    def _settle(self, failed: job.Job, error: Exception) -> None:
        match retry.decide(failed, error):
            case retry.Requeue(delay_seconds=delay):
                logger.warning("job %s failed, attempt %d, again in %d s", failed.id, failed.attempts, delay)
                self._queue.put(failed, delay)
            case retry.Park(reason=reason):
                logger.error("job %s parked: %s", failed.id, reason)
                self._lot.park(failed, reason)
