# Notes for the release

- Parsing: `parse_lazy` is many times faster than `parse_eager` on the export of 60,000 orders, as `python3 bench.py` shows. The importer switches to it.
