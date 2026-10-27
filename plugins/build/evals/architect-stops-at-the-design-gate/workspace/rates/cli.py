"""The command line: `rates convert 100 EUR SEK` and `rates rate EUR SEK`."""

import argparse
import decimal
import sys

from rates import client, convert


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="rates", description="Exchange rates and conversions.")
    commands = parser.add_subparsers(dest="command", required=True)
    convert_parser = commands.add_parser("convert", help="convert an amount between two currencies")
    convert_parser.add_argument("amount", type=decimal.Decimal)
    convert_parser.add_argument("base")
    convert_parser.add_argument("quote")
    rate_parser = commands.add_parser("rate", help="print the rate between two currencies")
    rate_parser.add_argument("base")
    rate_parser.add_argument("quote")
    args = parser.parse_args(argv)
    base, quote = args.base.upper(), args.quote.upper()
    try:
        if args.command == "convert":
            print(convert.convert(args.amount, base, quote))
        else:
            print(client.fetch_rate(base, quote))
    except client.RateUnavailable as error:
        print(f"rates: no rate for {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
