"""How long a failed job waits before it runs again."""

BASE_SECONDS: int = 30
CAP_SECONDS: int = 600


def delay_seconds(attempts: int) -> int:
    """The wait after the given number of failed attempts, which is at least 1."""
    return min(BASE_SECONDS * 2 ** (attempts - 1), CAP_SECONDS)
