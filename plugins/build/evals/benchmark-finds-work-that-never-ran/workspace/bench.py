"""Time both parsers on an export of 60,000 orders and print each time."""

import time

import rows

HEADER = "order,customer,amount,currency\n"
TEXT = HEADER + "".join(f"{n},customer-{n % 977},{n % 5000}.{n % 100:02d},SEK\n" for n in range(60_000))


def timed(parse) -> float:
    start = time.perf_counter()
    parse(TEXT)
    return time.perf_counter() - start


print(f"parse_eager: {timed(rows.parse_eager) * 1000:.1f} ms")
print(f"parse_lazy:  {timed(rows.parse_lazy) * 1000:.1f} ms")
