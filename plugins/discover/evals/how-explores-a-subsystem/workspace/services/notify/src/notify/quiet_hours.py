"""The hours of the night in which no recipient is messaged."""

import datetime as dt

START: dt.time = dt.time(21, 0)
END: dt.time = dt.time(7, 0)


def earliest_send(now: dt.datetime) -> dt.datetime:
    """When a message decided on at `now` may go out, with `now` in the recipient's local time.

    At once outside the quiet hours, and otherwise at the moment they end.
    """
    if now.time() >= START:
        return dt.datetime.combine(now.date() + dt.timedelta(days=1), END, tzinfo=now.tzinfo)
    if now.time() < END:
        return dt.datetime.combine(now.date(), END, tzinfo=now.tzinfo)
    return now
