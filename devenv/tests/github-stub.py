#!/usr/bin/env python3
"""A stub of GitHub's REST API for the fixture tests of agent-identity.

It serves canned answers from a directory: a request is answered from
<root>/<caller>/<METHOD> <path>.json, where the caller is the client id of the
App whose JSON Web Token signs the request, or "any" for the file that serves
every caller. A file holds {"status": <code>, "body": <answer>}; a request with
no file gets 404. A token signed by an App is checked against
<root>/<client id>/public.pem, with RS256 and a lifetime of ten minutes at most,
as GitHub checks it, and a bad one gets 401.

Usage: github-stub.py <root> <port file>. It writes the port it listens on to
the port file, and serves until it is killed.
"""

import http.server
import json
import pathlib
import sys
import typing as t

import jwt

MAX_JWT_SECONDS: t.Final = 600


class Stub(http.server.BaseHTTPRequestHandler):
    """Answers each request from the directory, the server's first argument."""

    root: t.ClassVar[pathlib.Path]

    def caller(self) -> str | None:
        """Return the client id that signed the request, "any" for another caller, or None for a bad token."""
        authorization = self.headers.get("Authorization", "")
        bearer = authorization.removeprefix("Bearer ")
        if bearer.count(".") != 2:  # noqa: PLR2004  # the three parts of a JSON Web Token
            return "any"
        issuer = t.cast("object", jwt.decode(bearer, options={"verify_signature": False}).get("iss"))
        key = self.root / str(issuer) / "public.pem"
        try:
            claims = t.cast(
                "dict[str, int]",
                jwt.decode(bearer, key.read_text(), algorithms=["RS256"], options={"require": ["exp", "iat", "iss"]}),
            )
        except (OSError, jwt.InvalidTokenError):
            return None
        return str(issuer) if claims["exp"] - claims["iat"] <= MAX_JWT_SECONDS else None

    def answer(self) -> None:
        """Send the canned answer, or 401 or 404."""
        caller = self.caller()
        if caller is None:
            self.send(401, {"message": "A JSON web token could not be decoded"})
            return
        name = f"{self.command} {self.path}.json".replace("/", "|")
        for directory in (caller, "any"):
            path = self.root / directory / name
            if path.exists():
                canned = t.cast("dict[str, object]", json.loads(path.read_text()))
                self.send(t.cast("int", canned["status"]), canned["body"])
                return
        self.send(404, {"message": "Not Found"})

    def send(self, status: int, body: object) -> None:
        """Answer with the status, and the body as JSON."""
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        _ = self.wfile.write(data)

    def do_GET(self) -> None:
        """Answer a GET from its canned file."""
        self.answer()

    def do_POST(self) -> None:
        """Answer a POST from its canned file, after reading its body."""
        _ = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        self.answer()

    @t.override
    def log_message(self, format: str, *args: object) -> None:
        """Keep request lines out of the test's output."""


def main() -> None:
    """Serve the directory until killed."""
    Stub.root = pathlib.Path(sys.argv[1])
    server = http.server.HTTPServer(("127.0.0.1", 0), Stub)
    _ = pathlib.Path(sys.argv[2]).write_text(str(server.server_address[1]))
    server.serve_forever()


if __name__ == "__main__":
    main()
