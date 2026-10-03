# Getting started

From nothing to a live HTTPS URL. About ten minutes, most of it waiting on DNS.

## What you need

- **A VPS with Docker on it**, reachable over SSH. That's the only hard requirement.
- **A domain** you can add one DNS record to.
- **The `docker` CLI** on your Mac — `brew install docker`. You do **not** need Docker
  Desktop or OrbStack running. That's the whole point.

## 1. Passwordless SSH

The remote Docker context talks to the VPS over SSH, so key auth has to work without a
prompt.

```bash
ssh-keygen -t ed25519 -C "remote-dev-kit"   # skip if you have a key already
ssh-copy-id you@YOUR_VPS_IP
ssh you@YOUR_VPS_IP 'echo ok'               # must print "ok", no password
```

If that last line asks for a password, stop here and fix it — nothing else will work.

## 2. One DNS record, forever

| Type | Name    | Content       | Proxy        |
|------|---------|---------------|--------------|
| A    | `*.dev` | `YOUR_VPS_IP` | **DNS only** |

Every project you ever deploy becomes `<name>.dev.yourdomain.com` off this one record. You
never touch DNS again.

**Keep it DNS-only** (grey cloud on Cloudflare). If it's proxied, Let's Encrypt's HTTP-01
challenge can't reach Traefik and you get no certificate.

`*.dev` sits safely alongside a production `*` record — it's a more specific name, so it
wins for `*.dev.*` and leaves everything else alone.

## 3. Install

```bash
curl -fsSL https://raw.githubusercontent.com/Enochthedev/remote-dev-kit/main/install-global.sh | bash
# or:  brew install --HEAD Enochthedev/tap/rdk
```

That puts `rdk` on your PATH and the stacks in `~/.remote-dev-kit`. Install once; it works
in every project after that.

Then tell rdk about your server — once, for every project you'll ever deploy:

```bash
rdk setup       # asks for VPS, SSHes in, DETECTS the proxy (coolify / bare),
                # asks your ACME email + base domain, saves ~/.config/rdk/config
```

After `rdk setup`, a new project's `.env.remote` is three lines you mostly don't edit
(name, host, port) — everything machine-level is inherited. Skip `setup` and `rdk init`
falls back to the full template with every field inline.

## 4. Deploy something

```bash
cd ~/Code/your-project

rdk init        # writes .env.remote — the only file rdk adds to your repo
                # (need a database? rdk init --db postgres also scaffolds
                #  Postgres+Redis with a generated password and DATABASE_URL)

rdk connect     # creates the docker context for this project (once)
rdk proxy up    # bare VPS only — starts Traefik (once per server, not per project)
rdk up          # build on the VPS + deploy
```

Live at `https://<APP_HOST>`. 🎉

**Already running Coolify?** Skip `rdk proxy up` and set `PROXY_NETWORK=coolify` — Coolify
already owns ports 80/443 and you cannot run a second Traefik next to it.

## 5. Iterate

```bash
rdk up          # redeploy with your latest code (layer cache makes it quick)
rdk watch       # live-sync edits into the running container — no redeploy per change
rdk logs        # follow logs
rdk down        # wipe it from the VPS: containers, images, volumes
```

`rdk watch` streams changed files straight into the container, so a dev server with reload
(`uvicorn --reload`, `next dev`, `nodemon`) picks them up instantly. Background workers
(Celery, queues) still need an `rdk up` to see new code.

## The mental model

Your code never lands on the VPS as a folder. `rdk up` sends a build context over SSH, the
VPS builds an **image**, and the container runs from that image. There's no bind-mount and
no source directory on the server — `rdk down` and it's genuinely gone.

Which also means: **the running app only contains the branch you built from.** To try
another branch, check it out and redeploy.

```bash
git checkout feat/some-feature
rdk up          # same URL, now running that branch
```

## Next

- [CLI reference](cli.md) — every command.
- [VS Code extension](vscode.md) — the same thing without the terminal.
- [Troubleshooting](troubleshooting.md) — read this when something is broken.
