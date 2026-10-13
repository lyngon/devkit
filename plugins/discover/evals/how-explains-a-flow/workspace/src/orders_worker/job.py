"""The envelope a job travels in between the queue and the consumer."""

import dataclasses


@dataclasses.dataclass(frozen=True, slots=True)
class Job:
    """One unit of work. An envelope is never changed: a retry is a new envelope with the same id."""

    id: str
    payload: bytes
    attempts: int = 0
