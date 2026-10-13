"""Which changes of status a recipient hears about, and in what words."""

import collections.abc as ct

_TEXTS: ct.Mapping[str, str] = {
    "out-for-delivery": "Your parcel is on the vehicle and arrives today.",
    "delivered": "Your parcel has been delivered.",
    "returned": "Your parcel is on its way back to the sender.",
}

ALWAYS_SENT: str = "delivered"


def text_for(status: str) -> str | None:
    """The message for a status, or None for a status that recipients are not told about."""
    return _TEXTS.get(status)
