"""What happens to a job whose handler failed."""

import dataclasses

from orders_worker import backoff, job

MAX_ATTEMPTS: int = 7


class PermanentFailure(Exception):
    """A handler raises this when running the job again cannot succeed."""


@dataclasses.dataclass(frozen=True, slots=True)
class Requeue:
    """Run the job again after the delay."""

    delay_seconds: int


@dataclasses.dataclass(frozen=True, slots=True)
class Park:
    """Take the job out of the queue and keep it for a person."""

    reason: str


def decide(failed: job.Job, error: Exception) -> Requeue | Park:
    """The verdict for a job that has just failed. `failed.attempts` counts this failure."""
    if isinstance(error, PermanentFailure):
        return Park(reason=f"permanent: {error}")
    if failed.attempts >= MAX_ATTEMPTS:
        return Park(reason=f"gave up after {failed.attempts} attempts: {error}")
    return Requeue(delay_seconds=backoff.delay_seconds(failed.attempts))
