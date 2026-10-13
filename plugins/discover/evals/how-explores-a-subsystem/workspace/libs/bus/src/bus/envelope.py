"""The envelope every message travels in on the bus."""

import dataclasses


@dataclasses.dataclass(frozen=True, slots=True)
class Envelope:
    """One message. The bus keeps the order of the envelopes that share a key, and of no others."""

    topic: str
    key: str
    body: bytes
