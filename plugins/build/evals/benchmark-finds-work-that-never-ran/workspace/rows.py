"""Parse the rows of a CSV export of orders."""

import collections.abc as ct
import csv
import io


def parse_eager(text: str) -> list[dict[str, str]]:
    """Return every row of the export, each as a mapping from column to value."""
    return list(csv.DictReader(io.StringIO(text)))


def parse_lazy(text: str) -> ct.Iterator[dict[str, str]]:
    """Yield the rows of the export one at a time, each as a mapping from column to value."""
    return (row for row in csv.DictReader(io.StringIO(text)))
