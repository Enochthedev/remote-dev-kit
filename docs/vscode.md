# The VS Code extension

Everything the CLI does, from the sidebar. Same engine underneath — the extension shells
out to the same stacks, so you can mix and match freely: deploy from the sidebar, tail logs
from your terminal.

**Repo:** [Enochthedev/remote-dev-kit-vscode](https://github.com/Enochthedev/remote-dev-kit-vscode)

## Install

Grab the `.vsix` from the extension repo's releases and:

```
Extensions → ⋯ → Install from VSIX…
```

Or from the command line:

```bash
code --install-extension remote-dev-kit-0.1.0.vsix
```

You still need the VPS and the DNS record from [Getting started](getting-started.md) — the
extension is a front-end, not a replacement for the setup.

## Use it

Open the **Remote Dev Kit** view in the sidebar. It gives you:

| Action | Same as |
|---|---|
| **Configure…** | editing `.env.remote` by hand |
| **Connect to VPS** | `rdk connect` |
| **Start Proxy** | `rdk proxy up` (bare VPS only) |
| **Deploy** | `rdk up` |
| **Watch (Hot Reload)** | `rdk watch` |
| **Logs** | `rdk logs` |
| **Status** | `rdk ps` |
| **Open in Browser** | opens `https://<APP_HOST>` |
| **Destroy** | `rdk down` — images and volumes, gone |

The normal loop is **Configure… → Connect → Deploy → Open in Browser**. After that you
mostly press **Deploy**, or leave **Watch** running while you work.

## Configuring it

**Configure…** writes the same `.env.remote` the CLI reads. There is only one config file
and both tools use it, so nothing can drift out of sync.

Settings map one-to-one onto the `.env.remote` keys:

| Setting | Key |
|---|---|
| `remoteDevKit.projectName` | `PROJECT_NAME` |
| `remoteDevKit.appHost` | `APP_HOST` |
| `remoteDevKit.appPort` | `APP_PORT` |
| `remoteDevKit.vpsSsh` | `VPS_SSH` |
| `remoteDevKit.stack` | `COMPOSE_FILE` |
| `remoteDevKit.appService` | `APP_SERVICE` |
| `remoteDevKit.appDockerfile` | `APP_DOCKERFILE` |
| `remoteDevKit.proxyMode` / `proxyNetwork` | `PROXY_NETWORK` |
| `remoteDevKit.certResolver` / `certEntrypoint` | `CERT_RESOLVER` / `CERT_ENTRYPOINT` |
| `remoteDevKit.acmeEmail` | `ACME_EMAIL` |

## If you'd rather not install anything

The per-project installer drops a `.vscode/tasks.json`, which gives you the same commands
through **⇧⌘P → Run Task**:

```
remote: up · watch · logs · ps · down
```

No extension, no sidebar, but it works.

## When the sidebar looks dead

The view only lights up in a folder that has a `.env.remote`. If it's empty, you haven't run
**Configure…** (or `rdk init`) in this project yet — that's all it means.

If a command fails, the output shows the underlying `docker` invocation. Run the same thing
in a terminal and you'll get the real error; the usual suspects are in
[Troubleshooting](troubleshooting.md).
