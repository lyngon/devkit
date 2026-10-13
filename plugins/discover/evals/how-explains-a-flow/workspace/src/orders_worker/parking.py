"""The jobs that left the queue without succeeding."""

import dataclasses

from orders_worker import job


@dataclasses.dataclass(frozen=True, slots=True)
class Parked:
    """A job that will not run again on its own, and why."""

    failed: job.Job
    reason: str


class ParkingLot:
    """Holds parked jobs by id until a person replays them."""

    def __init__(self) -> None:
        self._parked: dict[str, Parked] = {}

    def park(self, failed: job.Job, reason: str) -> None:
        """Keep the job. A job parked twice keeps its latest reason."""
        self._parked[failed.id] = Parked(failed=failed, reason=reason)

    def replay(self, job_id: str) -> job.Job:
        """Hand a parked job back with a fresh attempt count. Raises KeyError for an id that is not parked."""
        parked = self._parked.pop(job_id)
        return dataclasses.replace(parked.failed, attempts=0)
