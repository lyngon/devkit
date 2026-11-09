#!/usr/bin/env python3
"""Give the agents of a Claude Code session a GitHub identity of their own, a GitHub App.

The operator's machine declares the Apps it holds a key for in lyngon/agent-apps.toml
under XDG_CONFIG_HOME (~/.config when unset), one [[app]] table each, in order:

  [[app]]
  client_id = "Iv23li..."
  key_file = "/run/secrets/lyngon-developer-key"

A repository declares no App. Of the declared Apps installed on the repository, the one
whose owner owns the repository acts, and otherwise the first in the file.

  session         what the repo plugin's SessionStart hook runs: export lines for the
                  session's environment file on standard output, and one message for the
                  session's context on standard error
  token           print an installation token, from a cache under XDG_RUNTIME_DIR while
                  it has five minutes left, else a new one; the line that every Bash
                  command of the session reads runs agent_token.py, which reads the
                  cache alone and runs this only to mint
  git-credential  the same token for git, as its credential helper for GitHub
  create-app      create an App from the manifest template, through GitHub's own page

A token holding a permission that the template does not grant is refused, and so is a key
file that anyone but its owner can read. Where a declared App cannot serve, the session
fails closed: GH_TOKEN holds a value that GitHub rejects, git's credential helper answers
quit, and the message says why and what to do. It never falls back to the operator's token.

The baseline module builds the command agent-identity from this file and passes the
template, whether the repository turned agent identity on, and the command's own path.
GITHUB_API_URL and GITHUB_SERVER_URL point it at another GitHub, as in GitHub Actions.
"""

import argparse
import collections.abc as ct
import dataclasses
import html
import http
import http.client
import http.server
import json
import os
import pathlib
import re
import secrets
import shlex
import subprocess
import sys
import tempfile
import time
import tomllib
import typing as t
import urllib.error
import urllib.parse
import urllib.request
import webbrowser

import agent_token  # pyright: ignore[reportImplicitRelativeImport]  # a program run as a file, beside the module
import jwt

HOW_TO: t.Final = "https://github.com/lyngon/devkit/blob/main/devenv/agent-identity.md"
# What GH_TOKEN holds when no App can serve: GitHub answers it with 401.
UNAVAILABLE: t.Final = "agent-identity-unavailable"
LEVELS: t.Final = {"read": 1, "write": 2, "admin": 3}
TIMEOUT_SECONDS: t.Final = 10
# How long create-app waits for GitHub's page to send the person back.
CREATE_TIMEOUT_SECONDS: t.Final = 600


class IdentityError(Exception):
    """An App cannot serve. The message is a clause for the operator, saying why and what to do."""


@dataclasses.dataclass(frozen=True, slots=True)
class DeclaredApp:
    """An App that the operator's machine holds a key for."""

    client_id: str
    key_file: pathlib.Path


@dataclasses.dataclass(frozen=True, slots=True)
class Repository:
    """A repository on GitHub, as `origin` names it."""

    owner: str
    name: str

    @t.override
    def __str__(self) -> str:
        return f"{self.owner}/{self.name}"


@dataclasses.dataclass(frozen=True, slots=True)
class App:
    """What GitHub says about a declared App."""

    declared: DeclaredApp
    name: str
    slug: str
    owner: str


@dataclasses.dataclass(frozen=True, slots=True)
class Installed:
    """A declared App with its installation on one repository."""

    app: App
    installation_id: int


@dataclasses.dataclass(frozen=True, slots=True)
class Settings:
    """What the baseline module passes: the template, its permissions, the option, and the command's path."""

    template: dict[str, object]
    granted: dict[str, str]
    enabled: bool
    program: str


@dataclasses.dataclass(frozen=True, slots=True)
class GitHub:
    """The GitHub that the program talks to."""

    api: str
    server: str

    @property
    def host(self) -> str:
        """The host of the web server, which is the host of a GitHub remote."""
        return urllib.parse.urlsplit(self.server).hostname or ""

    def call(self, method: str, path: str, bearer: str | None) -> dict[str, object] | None:
        """Return GitHub's JSON answer, or None for 404. Raises IdentityError for any other failure."""
        request = urllib.request.Request(  # noqa: S310  # the URL is GITHUB_API_URL or https://api.github.com
            f"{self.api}{path}",
            method=method,
            data=None if method == "GET" else b"{}",
            headers={
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": "lyngon-agent-identity",
                **({"Authorization": f"Bearer {bearer}"} if bearer else {}),
            },
        )
        try:
            opened = t.cast("http.client.HTTPResponse", urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS))  # noqa: S310  # as above
            with opened as response:
                answer = t.cast("object", json.loads(response.read()))
        except urllib.error.HTTPError as error:
            if error.code == http.HTTPStatus.NOT_FOUND:
                return None
            raise IdentityError(f"GitHub answered {error.code} to {method} {path}") from error
        except (urllib.error.URLError, TimeoutError) as error:
            raise IdentityError(f"GitHub could not be reached at {self.api} ({error})") from error
        return json_object(answer, f"GitHub's answer to {method} {path}")


def json_object(value: object, what: str) -> dict[str, object]:
    """Return the value as an object with string keys. Raises IdentityError when it is none."""
    if not isinstance(value, dict):
        raise IdentityError(f"{what} is no JSON object")
    return t.cast("dict[str, object]", value)


def field[T](table: dict[str, object], key: str, kind: type[T], what: str) -> T:
    """Return the value at the key when it has the type. Raises IdentityError naming it otherwise."""
    value = table.get(key)
    # A JSON true is an int to isinstance, and never an id.
    if not isinstance(value, kind) or (isinstance(value, bool) and kind is not bool):
        raise IdentityError(f"{what} has no {kind.__name__} {key}")
    return value


def levels(table: dict[str, object], what: str) -> dict[str, str]:
    """Return a table of permissions, each a name and a level."""
    return {name: field(table, name, str, what) for name in table}


def printable(text: str) -> str:
    """Return the text without control characters, which a value from git or GitHub may hold."""
    return "".join(character for character in text if character.isprintable())


def parse_origin(url: str, host: str) -> Repository | None:
    """Return the repository that a remote URL names on the GitHub at the host, or None for any other URL."""
    scp = re.fullmatch(r"[^@/:]+@([^:/]+):([^/]+)/([^/]+?)(?:\.git)?/?", url)
    if scp:
        found_host, owner, name = scp.groups()
    else:
        parts = urllib.parse.urlsplit(url)
        path = re.fullmatch(r"/([^/]+)/([^/]+?)(?:\.git)?/?", parts.path)
        if parts.scheme not in {"https", "ssh"} or path is None:
            return None
        found_host = parts.hostname or ""
        owner, name = path.groups()
    return Repository(owner, name) if found_host == host else None


def declaration_path() -> pathlib.Path:
    """Return the path of the machine's declaration."""
    config = os.environ.get("XDG_CONFIG_HOME") or str(pathlib.Path.home() / ".config")
    return pathlib.Path(config) / "lyngon" / "agent-apps.toml"


def read_declaration(path: pathlib.Path) -> tuple[DeclaredApp, ...]:
    """Return the Apps the machine declares, none when the file does not exist. Raises IdentityError for a bad file."""
    if not path.exists():
        return ()
    try:
        tables = t.cast("object", tomllib.loads(path.read_text()).get("app", []))
    except (OSError, tomllib.TOMLDecodeError, UnicodeDecodeError) as error:
        raise IdentityError(f"{path} cannot be read ({error})") from error
    if not isinstance(tables, list):
        raise IdentityError(f"{path} holds an app that is no list of [[app]] tables")
    apps: list[DeclaredApp] = []
    for number, table in enumerate(t.cast("list[object]", tables), start=1):
        what = f"the [[app]] number {number} of {path}"
        entry = json_object(table, what)
        key_file = pathlib.Path(field(entry, "key_file", str, what)).expanduser()
        if not key_file.is_absolute():
            raise IdentityError(f"{what} has a key_file that is no absolute path")
        apps.append(DeclaredApp(field(entry, "client_id", str, what), key_file))
    return tuple(apps)


def read_key(app: DeclaredApp) -> str:
    """Return the App's private key. Raises IdentityError when anyone but its owner, the operator, can read it."""
    try:
        status = app.key_file.stat()
        key = app.key_file.read_text()
    except OSError as error:
        raise IdentityError(
            f"the key file {app.key_file} of the App {app.client_id} cannot be read ({error})"
        ) from error
    if status.st_uid != os.getuid() or status.st_mode & 0o077:
        reason = (
            f"someone else than you can read the key file {app.key_file} of the App {app.client_id} "
            f"(mode {status.st_mode & 0o777:o}); make it yours alone with chmod 600"
        )
        raise IdentityError(reason)
    return key


def app_jwt(app: DeclaredApp, now: float) -> str:
    """Return the JSON Web Token that the App signs to ask GitHub about itself and for installation tokens."""
    issued = int(now) - 60
    return jwt.encode({"iat": issued, "exp": issued + 540, "iss": app.client_id}, read_key(app), algorithm="RS256")


def describe(github: GitHub, app: DeclaredApp, now: float) -> App:
    """Return what GitHub says about the App."""
    found = github.call("GET", "/app", app_jwt(app, now))
    if found is None:
        raise IdentityError(f"GitHub knows no App with the client id {app.client_id}")
    what = f"GitHub's answer about the App {app.client_id}"
    owner = json_object(found.get("owner"), what)
    return App(
        app,
        printable(field(found, "name", str, what)),
        printable(field(found, "slug", str, what)),
        printable(field(owner, "login", str, what)),
    )


def installation(github: GitHub, app: App, repository: Repository, now: float) -> Installed | None:
    """Return the App's installation on the repository, or None when it is not installed there."""
    found = github.call("GET", f"/repos/{repository}/installation", app_jwt(app.declared, now))
    if found is None:
        return None
    return Installed(app, field(found, "id", int, f"GitHub's answer about {repository}"))


def choose(installed: ct.Sequence[Installed], repository: Repository) -> Installed | None:
    """Return the App that acts: the one whose owner owns the repository, else the first."""
    owners = (each for each in installed if each.app.owner.casefold() == repository.owner.casefold())
    return next(owners, installed[0] if installed else None)


def acting_app(github: GitHub, declared: ct.Sequence[DeclaredApp], repository: Repository, now: float) -> Installed:
    """Return the declared App that acts on the repository. Raises IdentityError, with the fix, when none can."""
    apps = [describe(github, app, now) for app in declared]
    acting = choose([found for app in apps if (found := installation(github, app, repository, now))], repository)
    if acting is None:
        links = " or ".join(f"{app.name} ({github.server}/apps/{app.slug}/installations/new)" for app in apps)
        reason = (
            f"no App this machine declares is installed on {repository}; its owner {repository.owner} "
            f"can install {links}, or the repository can set lyngon.agentIdentity.enable = false in devenv.nix "
            "to let agents act as the operator"
        )
        raise IdentityError(reason)
    return acting


def excess(held: dict[str, str], granted: dict[str, str]) -> list[str]:
    """Return each permission a token holds above what the template grants, as `name: level`."""
    return sorted(
        f"{name}: {level}"
        for name, level in held.items()
        if LEVELS.get(level, len(LEVELS) + 1) > LEVELS.get(granted.get(name, ""), 0)
    )


def write_cache(path: pathlib.Path, answer: dict[str, object]) -> None:
    """Write GitHub's answer to the cache in one step, readable by its owner alone."""
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as file:
        json.dump(answer, file)
    _ = pathlib.Path(file.name).replace(path)


def token(github: GitHub, app: DeclaredApp, installation_id: int, granted: dict[str, str], now: float) -> str:
    """Return a token for the installation: the cached one while agent_token finds it fresh, else a new one."""
    path = agent_token.cache_path(installation_id)
    if path is None:
        raise IdentityError("XDG_RUNTIME_DIR is not set, so there is no place only you can read to keep a token")
    if (cached := agent_token.fresh(path, now)) is not None:
        return cached
    request = f"/app/installations/{installation_id}/access_tokens"
    answer = github.call("POST", request, app_jwt(app, now))
    if answer is None:
        raise IdentityError(f"the installation {installation_id} of the App {app.client_id} is gone")
    what = f"GitHub's answer to POST {request}"
    if over := excess(levels(json_object(answer.get("permissions"), what), what), granted):
        reason = (
            f"the App {app.client_id} holds {', '.join(over)}, which its manifest template does not grant; "
            "an owner must take the permission back on GitHub, or add it to the template first"
        )
        raise IdentityError(reason)
    value = field(answer, "token", str, what)
    write_cache(path, answer)
    return value


def bot_email(github: GitHub, app: App, bearer: str) -> str:
    """Return the email address that links a commit to the App's bot user."""
    login = f"{app.slug}[bot]"
    found = github.call("GET", f"/users/{urllib.parse.quote(login)}", bearer)
    if found is None:
        raise IdentityError(f"GitHub knows no bot user {login}")
    return f"{field(found, 'id', int, f'GitHub answer about {login}')}+{login}@users.noreply.{github.host}"


def git(root: pathlib.Path, *arguments: str) -> str | None:
    """Return what a git command prints at the root, or None when it fails or prints nothing."""
    done = subprocess.run(["git", "-C", str(root), *arguments], capture_output=True, text=True, check=False)
    if done.returncode != 0:
        return None
    return printable(done.stdout.strip()) or None


def export(name: str, value: str) -> str:
    """Return a line of the environment file that bash and zsh both read back as the value."""
    return f"export {name}={shlex.quote(value)}"


def git_config(github: GitHub, helper: list[str]) -> list[str]:
    """Return the lines that make git ask the helper for GitHub's credentials, and reach GitHub over https.

    git asks every helper in its list, so the list is emptied first, and a push over ssh would go out with
    the operator's own key, so ssh remotes on GitHub are rewritten to https.
    """
    entries = [
        (f"credential.{github.server}.helper", ""),
        (f"credential.{github.server}.helper", f"!{shlex.join(helper)}"),
        (f"url.{github.server}/.insteadOf", f"git@{github.host}:"),
        (f"url.{github.server}/.insteadOf", f"ssh://git@{github.host}/"),
    ]
    lines = [export("GIT_CONFIG_COUNT", str(len(entries)))]
    for number, (key, value) in enumerate(entries):
        lines += [export(f"GIT_CONFIG_KEY_{number}", key), export(f"GIT_CONFIG_VALUE_{number}", value)]
    return lines


def closed(github: GitHub, settings: Settings, reason: str) -> tuple[list[str], str]:
    """Return the exports and the message of a session whose declared Apps cannot serve."""
    lines = [export("GH_TOKEN", UNAVAILABLE), *git_config(github, [settings.program, "git-credential"])]
    message = (
        f"Agent identity: agents cannot reach GitHub in this session, because {reason}. "
        "Tell the operator, and never unset GH_TOKEN or the GIT_CONFIG_ variables to act as them. "
        f"A fix takes effect in a new session. See {HOW_TO}"
    )
    return lines, message


def operator_identity(reason: str) -> tuple[list[str], str]:
    """Return the exports and the message of a session that keeps the operator's identity."""
    return [], f"Agent identity: agents act on GitHub as you, the operator, because {reason}."


def session(github: GitHub, settings: Settings, root: pathlib.Path, now: float) -> tuple[list[str], str]:
    """Return the session's export lines and its message: the App that acts, the operator, or a closed door."""
    if not settings.enabled:
        return operator_identity("this repository sets lyngon.agentIdentity.enable = false in devenv.nix")
    origin = git(root, "remote", "get-url", "origin")
    repository = None if origin is None else parse_origin(origin, github.host)
    if repository is None:
        return operator_identity(f"the origin of this repository is not on {github.host}")
    path = declaration_path()
    try:
        declared = read_declaration(path)
        if not declared:
            reason = (
                f"this machine declares no GitHub App for agents in {path}; "
                f"to give them an identity of their own, see {HOW_TO}"
            )
            return operator_identity(reason)
        acting = acting_app(github, declared, repository, now)
        current = token(github, acting.app.declared, acting.installation_id, settings.granted, now)
        email = bot_email(github, acting.app, current)
    except IdentityError as error:
        return closed(github, settings, str(error))
    bot = f"{acting.app.slug}[bot]"
    options = ["--installation", str(acting.installation_id), "--client-id", acting.app.declared.client_id]
    options += ["--key-file", str(acting.app.declared.key_file)]
    lines = [
        export("GIT_AUTHOR_NAME", bot),
        export("GIT_AUTHOR_EMAIL", email),
        export("GIT_COMMITTER_NAME", bot),
        export("GIT_COMMITTER_EMAIL", email),
    ]
    name, mail = git(root, "config", "user.name"), git(root, "config", "user.email")
    if name and mail:
        lines.append(export("LYNGON_AGENT_OPERATOR", f"{name} <{mail}>"))
        credit = f"and every commit they make names you, {name} <{mail}>, as its co-author"
    else:
        credit = "and their commits name no co-author, because git has no user.name and user.email here"
    lines += git_config(github, [settings.program, "git-credential", *options])
    fast = [sys.executable, str(pathlib.Path(__file__).with_name("agent_token.py"))]
    fast += ["--installation", str(acting.installation_id), "--", settings.program, "token", *options]
    lines.append(f'export GH_TOKEN="$({shlex.join(fast)})"')
    message = (
        f"Agent identity: agents in this session act on GitHub as {bot}, the App {acting.app.name}, {credit}. "
        "Never unset GH_TOKEN, the GIT_CONFIG_ variables or the git author to act as the operator."
    )
    return lines, message


class ManifestServer(http.server.HTTPServer):
    """create-app's listener on 127.0.0.1: the page that sends the manifest to GitHub, and GitHub's way back."""

    def __init__(self) -> None:
        super().__init__(("127.0.0.1", 0), ManifestPage)
        self.page: str = ""
        self.state: str = secrets.token_urlsafe(16)
        self.code: str | None = None

    @property
    def url(self) -> str:
        """The address of the page."""
        return f"http://127.0.0.1:{self.server_address[1]}/"


class ManifestPage(http.server.BaseHTTPRequestHandler):
    """Serves the page that posts the manifest, and takes the code that GitHub sends back with the state."""

    def do_GET(self) -> None:
        """Serve the page, or take the code."""
        server = t.cast("ManifestServer", self.server)
        parts = urllib.parse.urlsplit(self.path)
        query = urllib.parse.parse_qs(parts.query)
        if parts.path == "/":
            self.reply(server.page)
        elif parts.path == "/callback" and query.get("state") == [server.state] and "code" in query:
            server.code = query["code"][0]
            self.reply("<!doctype html><title>Done</title><p>GitHub created the App. Go back to the terminal.</p>")
        else:
            self.send_error(http.HTTPStatus.NOT_FOUND)

    def reply(self, page: str) -> None:
        """Send the page."""
        body = page.encode()
        self.send_response(http.HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        _ = self.wfile.write(body)

    @t.override
    def log_message(self, format: str, *args: object) -> None:
        """Keep request lines out of the terminal."""


@dataclasses.dataclass(frozen=True, slots=True)
class NewApp:
    """What create-app asks GitHub for: the App's name, the account that owns it, and who may install it."""

    name: str
    owner: str
    public: bool
    key_file: pathlib.Path


def create_app(github: GitHub, template: dict[str, object], new: NewApp) -> str:
    """Create an App from the template on GitHub's page, write its key, and return what to do next."""
    account = github.call("GET", f"/users/{urllib.parse.quote(new.owner)}", None)
    if account is None:
        raise IdentityError(f"GitHub knows no account {new.owner}")
    organization = field(account, "type", str, f"GitHub's answer about {new.owner}") == "Organization"
    path = f"/organizations/{new.owner}/settings/apps/new" if organization else "/settings/apps/new"
    with ManifestServer() as server:
        manifest = {**template, "name": new.name, "public": new.public, "redirect_url": f"{server.url}callback"}
        action = f"{github.server}{path}?{urllib.parse.urlencode({'state': server.state})}"
        server.page = (
            '<!doctype html><meta charset="utf-8"><title>Create a GitHub App</title>'
            f'<form id="manifest" method="post" action="{html.escape(action)}">'
            f'<input type="hidden" name="manifest" value="{html.escape(json.dumps(manifest))}"></form>'
            "<p>Sending the manifest to GitHub.</p>"
            '<script>document.getElementById("manifest").submit()</script>'
        )
        print(f"Opening {server.url}, which sends the manifest to GitHub. Open it yourself if no browser starts.")
        _ = webbrowser.open(server.url)
        deadline = time.monotonic() + CREATE_TIMEOUT_SECONDS
        while server.code is None and (left := deadline - time.monotonic()) > 0:
            server.timeout = left
            server.handle_request()
        code = server.code
    if code is None:
        raise IdentityError(f"GitHub did not send you back within {CREATE_TIMEOUT_SECONDS} seconds")
    created = github.call("POST", f"/app-manifests/{urllib.parse.quote(code)}/conversions", None)
    if created is None:
        raise IdentityError("GitHub no longer knows the code it sent back; run create-app again")
    what = "GitHub's answer about the new App"
    descriptor = os.open(new.key_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as file:
        _ = file.write(field(created, "pem", str, what))
    slug, client_id = field(created, "slug", str, what), field(created, "client_id", str, what)
    return (
        f"GitHub created the App {field(created, 'name', str, what)} ({slug}), owned by {new.owner}.\n"
        f"Its private key is in {new.key_file}, which only you can read.\n\n"
        f"1. Install it on the repositories its agents work in: {github.server}/apps/{slug}/installations/new\n"
        f"2. Keep the key where only you can read it, and declare the App in {declaration_path()}:\n\n"
        f'[[app]]\nclient_id = "{client_id}"\nkey_file = "{new.key_file}"\n\n'
        f"See {HOW_TO}"
    )


def arguments() -> argparse.Namespace:
    """Parse the command line."""
    parser = argparse.ArgumentParser(prog="agent-identity", description="Give agents a GitHub App as identity.")
    _ = parser.add_argument("--manifest", type=pathlib.Path, required=True, help="the manifest template")
    _ = parser.add_argument("--enabled", choices=["true", "false"], required=True, help="lyngon.agentIdentity.enable")
    _ = parser.add_argument("--program", required=True, help="the command itself, for the lines it prints")
    commands = parser.add_subparsers(dest="command", required=True)
    session_command = commands.add_parser("session", help="resolve the identity of a session")
    _ = session_command.add_argument("--root", type=pathlib.Path, required=True, help="the session's repository")
    for name in ("token", "git-credential"):
        command = commands.add_parser(name, help=f"print an installation token ({name})")
        _ = command.add_argument("--installation", type=int)
        _ = command.add_argument("--client-id")
        _ = command.add_argument("--key-file", type=pathlib.Path)
        if name == "git-credential":
            _ = command.add_argument("action", nargs="?", default="get", help="what git asks: get, store or erase")
    create = commands.add_parser("create-app", help="create an App from the manifest template")
    _ = create.add_argument("--name", required=True, help="the App's name, unique on GitHub")
    _ = create.add_argument("--owner", required=True, help="the organization or user that owns the App")
    _ = create.add_argument("--public", action="store_true", help="let any account install the App")
    _ = create.add_argument("--key-file", type=pathlib.Path, required=True, help="a new file for the private key")
    return parser.parse_args()


def settings_from(parsed: argparse.Namespace) -> Settings:
    """Return the settings that the baseline module passed. Raises IdentityError for a bad template."""
    path = t.cast("pathlib.Path", parsed.manifest)
    template = json_object(t.cast("object", json.loads(path.read_text())), str(path))
    granted = levels(json_object(template.get("default_permissions"), str(path)), str(path))
    return Settings(template, granted, t.cast("str", parsed.enabled) == "true", t.cast("str", parsed.program))


def requested(parsed: argparse.Namespace) -> tuple[DeclaredApp, int]:
    """Return the App and the installation that token or git-credential names. Raises IdentityError for none."""
    installation_id = t.cast("int | None", parsed.installation)
    client_id, key_file = t.cast("str | None", parsed.client_id), t.cast("pathlib.Path | None", parsed.key_file)
    if installation_id is None or client_id is None or key_file is None:
        raise IdentityError("no App this machine declares can serve this session")
    return DeclaredApp(client_id, key_file), installation_id


def print_token(github: GitHub, settings: Settings, parsed: argparse.Namespace, *, for_git: bool) -> int:
    """Print the token for gh, or as git's credential helper answers. Returns 1 after failing closed."""
    try:
        app, installation_id = requested(parsed)
        value = token(github, app, installation_id, settings.granted, time.time())
    except IdentityError as error:
        print(f"agent-identity: agents cannot reach GitHub, because {error}. See {HOW_TO}", file=sys.stderr)
        print("quit=1" if for_git else UNAVAILABLE)
        return 1
    print(f"username=x-access-token\npassword={value}" if for_git else value)
    return 0


def main() -> int:
    """Run the command."""
    parsed = arguments()
    github = GitHub(
        (os.environ.get("GITHUB_API_URL") or "https://api.github.com").rstrip("/"),
        (os.environ.get("GITHUB_SERVER_URL") or "https://github.com").rstrip("/"),
    )
    settings = settings_from(parsed)
    command = t.cast("str", parsed.command)
    if command == "session":
        lines, message = session(github, settings, t.cast("pathlib.Path", parsed.root), time.time())
        print("\n".join(lines))
        print(message, file=sys.stderr)
        return 0
    if command == "create-app":
        try:
            new = NewApp(
                t.cast("str", parsed.name),
                t.cast("str", parsed.owner),
                t.cast("bool", parsed.public),
                t.cast("pathlib.Path", parsed.key_file),
            )
            print(create_app(github, settings.template, new))
        except (IdentityError, OSError) as error:
            print(f"agent-identity: {error}", file=sys.stderr)
            return 1
        return 0
    if command == "git-credential":
        # git writes what it asks about to standard input and may wait until it is read.
        _ = sys.stdin.read()
        if t.cast("str", parsed.action) != "get":
            return 0
    return print_token(github, settings, parsed, for_git=command == "git-credential")


if __name__ == "__main__":
    sys.exit(main())
