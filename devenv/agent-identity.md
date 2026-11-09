# How to give your agents a GitHub identity of their own

In a repository that enables the Lyngon baseline, the agents of a Claude Code session act on GitHub as a GitHub App, not as you.
GitHub then tells their issues, commits and pull requests from yours, and you can approve their pull requests.
Every commit an agent makes names you as co-author, so it still counts on your contribution graph.

Your machine declares the Apps it holds a key for, and the repository declares none.
When a session starts, the `repo` plugin asks the baseline's `agent-identity` which App serves the repository.
The answer is in the session's context, in one line that starts with "Agent identity:".

## Check what a session does now

In the repository, run:

```sh
agent-identity session --root .
```

The command prints the lines it gives a session, then its message.
It acts on nothing.

| Your machine and the repository | Agents act as |
| --- | --- |
| A declared App is installed on the repository | The App's bot, `<slug>[bot]` |
| Two declared Apps are installed on it | The App owned by the repository's owner, else the one declared first |
| No App is declared | You |
| The repository sets `lyngon.agentIdentity.enable = false` | You |
| `origin` is not on GitHub | You |
| Apps are declared, and none can serve the repository | Nobody: GitHub refuses the session, and the message says why |

## Use an App that already exists

Lyngon's people use Lyngon Developer, and its key is on every Lyngon development machine.
In a client's repository, the client installs it on the repositories it chooses: <https://github.com/apps/lyngon-developer/installations/new>.

For any other App, get a key of your own, then [store the key](#store-the-key) and [declare the App](#declare-the-app).
To get a key, ask an owner of the App to generate a private key in the App's settings on GitHub, under **Private keys**.
Each machine gets its own key, so that a lost machine is revoked by deleting its key, with no change to the others.

## Create an App for your organization

Create one App per organization, once.
Its name is unique across GitHub, so pick one that names your organization, such as "Acme Developer".

1. In a shell of a repository that enables the baseline, run:

   ```sh
   agent-identity create-app --name "Acme Developer" --owner acme --key-file "$XDG_RUNTIME_DIR/acme-developer.pem"
   ```

   Add `--public` if accounts other than yours may install the App, as client organizations install Lyngon Developer.

2. In the browser page that opens, check the name and click **Create GitHub App**.
3. Open the install link that the command prints, and install the App on the repositories its agents work in.

The command fills the manifest template, `agent-app-manifest.json` beside this file, with the name and the `--public` choice.
The template grants what a contributor needs (contents, pull requests, issues and workflows to write; actions, checks and statuses to read) and never `administration`, so an agent cannot edit the rules that bind it.

## Store the key

Keep the key in a file that only you can read:

```sh
chmod 600 "$XDG_RUNTIME_DIR/acme-developer.pem"
```

`agent-identity` refuses a key file that anyone else can read.
On NixOS with sops-nix, encrypt the key for the one machine, and declare it as a secret that you own:

```nix
sops.secrets."acme-developer-key" = {
  sopsFile = ./secrets/hosts/your-host/acme-developer-key.pem;
  format = "binary";
  owner = "you";
  mode = "0400";
};
```

The key never goes into a repository or a repository's `secretspec.toml`.
It belongs to your machine and serves every repository on it.

## Declare the App

List each App in `~/.config/lyngon/agent-apps.toml`, or under `XDG_CONFIG_HOME` when you set it:

```toml
[[app]]
client_id = "Iv23li..."
key_file = "/run/secrets/acme-developer-key"
```

`create-app` prints this table for a new App.
The client id is also on the App's settings page.
When two declared Apps are installed on one repository, the App owned by the repository's owner acts, else the one declared first.

The declaration takes effect in the next session.

## Turn agent identity off in a repository

To let agents act as the operator in a repository, set this in its `devenv.nix`:

```nix
lyngon.agentIdentity.enable = false;
```

## Fix a session that cannot reach GitHub

Each message names its cause, and the fix takes effect in a new session.

- **No App this machine declares is installed**: the repository's owner installs one of the Apps from the link in the message. Or the repository turns agent identity off.
- **Someone else than you can read the key file**: run `chmod 600` on the file the message names.
- **The App holds a permission that its manifest template does not grant**: an owner of the App takes the permission back in the App's settings. To grant it on purpose, change the template in the devkit first.
- **GitHub could not be reached**, or answered with an error: start a new session once GitHub answers.
- **`XDG_RUNTIME_DIR` is not set**: start Claude Code from a login session, which sets it.

## Know the limits

- It is not a sandbox. An agent runs as you, and can read the App's key and your own token. The identity catches honest mistakes and records who did what.
- A command you run in the session with `!` runs in the session's shell, so it acts as the App.
- A token serves the repository's owner only. From a client's repository, an agent cannot reach a repository of another owner.
