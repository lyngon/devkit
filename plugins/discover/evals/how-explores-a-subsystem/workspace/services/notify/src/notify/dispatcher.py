"""Turns changes of status into messages to recipients."""

import datetime as dt
import json
import typing as t

from bus import envelope
from notify import policy, quiet_hours, throttle


class Gateway(t.Protocol):
    """The provider that delivers a text message."""

    def send(self, parcel_id: str, text: str, not_before: dt.datetime) -> None:
        """Deliver the text to the parcel's recipient, at `not_before` or as soon after it as the provider can."""
        ...


class MalformedChange(Exception):
    """A message on the status topic whose body is not a change of status."""


class Dispatcher:
    """Decides for each change of status whether the recipient hears about it, and when."""

    def __init__(self, gateway: Gateway, limiter: throttle.Throttle) -> None:
        self._gateway: Gateway = gateway
        self._limiter: throttle.Throttle = limiter

    def on_status_changed(self, message: envelope.Envelope, now: dt.datetime) -> None:
        """Take one message of the status topic, with `now` in the recipient's local time.

        Raises MalformedChange for a message that is not a change of status.
        """
        try:
            fields = json.loads(message.body)
            parcel_id = str(fields["parcel"])
            status = str(fields["status"])
        except (KeyError, TypeError, ValueError) as error:
            raise MalformedChange(message.key) from error
        text = policy.text_for(status)
        if text is None:
            return
        # A delivery is always announced. The quiet hours still hold for it.
        if status != policy.ALWAYS_SENT and not self._limiter.allows(parcel_id, now):
            return
        self._gateway.send(parcel_id, text, quiet_hours.earliest_send(now))
        self._limiter.record(parcel_id, now)
