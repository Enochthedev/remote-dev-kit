<div align="center">

# 🛰️ remote-dev-kit

**Run your Docker projects on a VPS — not your Mac.**
Code stays on your laptop. Builds and containers live on the server. Every project gets its own HTTPS subdomain, automatically.

![shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)
![docker](https://img.shields.io/badge/docker-context-2496ED?logo=docker&logoColor=white)
![proxy](https://img.shields.io/badge/proxy-Traefik-24A1C1?logo=traefikproxy&logoColor=white)
![any language](https://img.shields.io/badge/stack-any%20language-blueviolet)
![license](https://img.shields.io/badge/license-MIT-green)

</div>

---

## Why

- 🧹 **Reclaim your Mac** — no local images, no build cache, no daemon. Quit Docker Desktop / OrbStack entirely.
- 🔒 **Code never leaves your machine** — it's baked into a throwaway image on the VPS, not synced as a folder. `./remote down` and it's *gone*.
- 🌐 **Instant HTTPS subdomains** — `myapp.dev.yourdomain.com`, cert and routing handled for you.
- 🧩 **Any language** — if it has a `Dockerfile`, it works. Node, Go, Rust, Python, PHP, static.
- 🖥️ **Just needs a VPS** — the kit brings its own Traefik. No PaaS required. (Already run Coolify? It plugs into that too.)

## Requirements

- A **VPS with Docker** installed, and **SSH access** to it. That's the only hard requirement.
- A **domain** with a wildcard record `*.dev` → your VPS IP (**DNS only** — see setup). One record covers every project, forever.
- The **`docker` CLI** on your Mac (no local daemon needed): `brew install docker`.

## How it works

```text
   your Mac                                   your VPS
 ┌───────────────┐                      ┌────────────────────────────┐
 │ code + docker │  build ctx over SSH  │  Docker builds the image   │
 │ CLI (no VM)   │ ───────────────────▶ │  Traefik routes + TLS      │
 │ ./remote up   │                      │  <app>.dev.domain.com  🔒  │
 └───────────────┘                      └────────────────────────────┘
        ▲                                            │
        └──────────  https://<app>.dev.domain.com ◀──┘
```

Your `docker` CLI targets the VPS via a **remote context** — the build happens *there*, so nothing lands on your Mac. The app is **baked into the image** (no bind-mount), so no editable source folder persists on the server.

---

## 🚀 Quick start

### 0. One-time: SSH key + DNS

**Passwordless SSH to your VPS** (the remote context needs key auth):

```bash
ssh-keygen -t ed25519 -C "remote-dev-kit"      # skip if you already have a key
ssh-copy-id youruser@YOUR_VPS_IP               # installs your key on the VPS
ssh youruser@YOUR_VPS_IP 'echo ok'             # must print "ok" with no password
```

**One wildcard DNS record** (set once, covers every project):

| Type | Name    | Content        | Proxy        |
|------|---------|----------------|--------------|
| A    | `*.dev` | `YOUR_VPS_IP`  | **DNS only** |

> Keep it **DNS only** (grey cloud on Cloudflare) so Traefik can issue Let's Encrypt certs.
> `*.dev` is safe next to a production `*` record — it's a more specific, separate name.

### 1. Install the kit into your project

```bash
cd ~/Code/your-project
curl -fsSL https://raw.githubusercontent.com/Enochthedev/remote-dev-kit/main/install.sh | bash
```

### 2. Configure — edit `.env.remote`

Set `PROJECT_NAME`, `APP_HOST`, `APP_PORT`, `VPS_SSH`, and pick a **proxy mode**:

| Your VPS | Set in `.env.remote` | Extra step |
|----------|----------------------|------------|
| **Bare** (just Docker) | `PROXY_NETWORK=web` + `ACME_EMAIL=...` | `./remote proxy up` (once per server) |
| **Runs Coolify/Traefik** | `PROXY_NETWORK=coolify` | none — skip the proxy step |

### 3. Deploy

```bash
./remote proxy up     # bare VPS only — starts Traefik (run once per server)
./remote init         # create the docker context for this project (run once)
./remote up           # build on the VPS + deploy
```

→ live at `https://<APP_HOST>` with automatic HTTPS. 🎉

---

## Iterating on your code

**Deploy new changes** — just run it again. `./remote up` rebuilds the image on the VPS
(Docker layer cache makes it fast) and recreates the containers with your latest code:

```bash
# edit code on your Mac …
./remote up          # → new version live at the same URL
```

**Hot reload** — sync edits live instead of redeploying each time:

```bash
./remote watch       # syncs your Mac edits into the running container
```

`watch` uses `docker compose watch` to stream changed files to the VPS container; your
dev server (e.g. Django's `runserver`/`uvicorn --reload`) picks them up instantly. Code
still never persists on the VPS — the sync is into the ephemeral container. (Web hot-reloads;
background workers like Celery pick changes up on their next `./remote up`.)

**Test a different branch** — the running app only contains the branch you built from.
To try another branch (a feature, a CMS, etc.), check it out and redeploy:

```bash
git checkout feat/some-feature
./remote up          # same URL, now running that branch
```

**VS Code** — the installer drops `.vscode/tasks.json`, so **⇧⌘P → Run Task** gives you
`remote: watch / up / logs / ps / down` without touching the terminal.

## Stacks

Pick one with `COMPOSE_FILE` in `.env.remote`:

| `COMPOSE_FILE` | Runs | Use for |
|---|---|---|
| **`docker-compose.remote.yml`** *(default)* | one web service from your `./Dockerfile` | **any** language / framework |
| `docker-compose.django.yml` | django · postgres · redis · mailpit · celery · flower | Cookiecutter-Django backends |

> Need a DB/cache in the generic stack? Add services to `docker-compose.remote.yml` on the `default` network — only web-facing services need the `proxy` network + `traefik.*` labels.

## Commands

| Command | Does |
|---|---|
| `./remote proxy up` | Bare VPS: start the kit's Traefik (once per server) |
| `./remote init` | Create the remote docker context for this project |
| `./remote up` | Build on the VPS + deploy |
| `./remote watch` | Deploy + live-sync edits to the VPS (hot reload) |
| `./remote down` | Tear down + delete images & volumes on the VPS |
| `./remote stop` | Stop containers (keep images/volumes) |
| `./remote logs [svc]` | Follow logs |
| `./remote ps` | List running services |
| `./remote manage …` | Run `manage.py` (Django stack) |
| `./remote sh` | Shell into the app container |

## Repo layout

```text
remote-dev-kit/
├── bin/
│   └── remote                     # the ./remote CLI (init · proxy · up · down · …)
├── stacks/
│   ├── docker-compose.remote.yml  # generic single-service stack (any language)
│   ├── docker-compose.django.yml  # full Cookiecutter-Django stack
│   └── traefik.yml                # the kit's own Traefik (bare-VPS mode)
├── .env.remote.example            # copy → .env.remote, the one file you edit
├── install.sh                     # drops the kit (flat) into any project
├── LICENSE
└── README.md
```

> `install.sh` fetches these and lays them **flat** into your project root — the compose build context has to be the project root, so `remote` + the compose files live there.

## Configuration — `.env.remote`

| Var | What it is |
|-----|------------|
| `PROJECT_NAME` | Namespaces containers, volumes & Traefik routers. Unique per project. |
| `APP_HOST` | Public host, e.g. `myapp.dev.yourdomain.com`. |
| `APP_PORT` | Port your app listens on inside the container. |
| `APP_SERVICE` | Primary service name (`app` generic · `django` for the Django stack). |
| `COMPOSE_FILE` | Which stack to run (see table above). |
| `APP_DOCKERFILE` | Path to your Dockerfile (generic stack). |
| `VPS_SSH` | `user@vps-ip` for the remote context. |
| `PROXY_NETWORK` | `web` (kit's Traefik) or `coolify` (existing proxy). |
| `ACME_EMAIL` | Let's Encrypt contact (bare-VPS/Traefik mode). |
| `CERT_RESOLVER` · `CERT_ENTRYPOINT` | Traefik resolver/entrypoint names (defaults: `letsencrypt` · `https`). |
| `MAIL_HOST` · `FLOWER_HOST` · `*_ENV_FILE` · `*_DOCKERFILE` | Django-stack extras. |

<details>
<summary><b>Django note</b></summary>

Let the app accept its new host (env-driven):

```python
ALLOWED_HOSTS += env.list("DJANGO_ALLOWED_HOSTS", default=[])
CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=[])
```

Set `DJANGO_ALLOWED_HOSTS` / `CSRF_TRUSTED_ORIGINS` in your app env file.
⚠️ **Never run `DEBUG=True` on a public host.**
</details>

<details>
<summary><b>Non-Django / other stacks</b></summary>

Point `APP_DOCKERFILE` at your Dockerfile and set `APP_PORT` to whatever it listens on.
For extra services, add them to `docker-compose.remote.yml`; give only web-facing ones the
`proxy` network + `traefik.*` labels (router rule = `Host(...)`, `loadbalancer.server.port` = your port).
</details>

---

<div align="center">
<sub>Build local · run remote · tear down clean.</sub>
</div>
