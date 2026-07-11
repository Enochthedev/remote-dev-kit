<div align="center">

# 🛰️ remote-dev-kit

**Run your Docker projects on a VPS — not your Mac.**
Code stays on your laptop. Builds and containers live on the server. Every project gets its own HTTPS subdomain, automatically.

![shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)
![docker](https://img.shields.io/badge/docker-context-2496ED?logo=docker&logoColor=white)
![proxy](https://img.shields.io/badge/proxy-Traefik%20%2F%20Coolify-24A1C1)
![any language](https://img.shields.io/badge/stack-any%20language-blueviolet)

</div>

---

## Why

- 🧹 **Reclaim your Mac** — no local images, no build cache, no daemon. Quit Docker Desktop / OrbStack entirely.
- 🔒 **Code never leaves your machine** — it's baked into a throwaway image on the VPS, not synced as a folder. `./remote down` and it's *gone*.
- 🌐 **Instant HTTPS subdomains** — `myapp.dev.yourdomain.com`, cert and routing handled for you.
- 🧩 **Any language** — if it has a `Dockerfile`, it works. Node, Go, Rust, Python, PHP, static.
- ♻️ **Set up once, reuse forever** — one wildcard DNS record covers every future project. Zero per-project DNS.

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

## Stacks

Pick one with `COMPOSE_FILE` in `.env.remote`:

| `COMPOSE_FILE` | Runs | Use for |
|---|---|---|
| **`docker-compose.remote.yml`** *(default)* | one web service from your `./Dockerfile` | **any** language / framework |
| `docker-compose.django.yml` | django · postgres · redis · mailpit · celery · flower | Cookiecutter-Django backends |

> Need a DB/cache in the generic stack? Add services to `docker-compose.remote.yml` on the `default` network — only web-facing services need the `proxy` network + `traefik.*` labels.

---

## ⚙️ One-time setup

<details open>
<summary><b>1. A VPS with a Traefik-based proxy</b> (e.g. Coolify)</summary>

Note two values (Coolify defaults shown):

```bash
docker network ls | grep coolify                                 # proxy network → coolify
docker inspect coolify-proxy 2>/dev/null | grep -i certresolver  # cert resolver → letsencrypt
```
</details>

<details open>
<summary><b>2. One scoped wildcard DNS record</b> — set once, covers every project</summary>

| Type | Name    | Content    | Proxy         |
|------|---------|------------|---------------|
| A    | `*.dev` | `<VPS IP>` | **DNS only**  |

Now `anything.dev.yourdomain.com` resolves to the VPS — **no per-project DNS, ever**.
Keep it **DNS only** (grey cloud on Cloudflare) so Traefik can issue certs via HTTP-01.
</details>

<details>
<summary><b>3. Docker CLI on your Mac</b> (no daemon needed)</summary>

```bash
brew install docker   # just the CLI — the VPS runs the engine
```
</details>

## 🚀 Per-project usage

```bash
# from your project root
curl -fsSL https://raw.githubusercontent.com/Enochthedev/remote-dev-kit/main/install.sh | bash

$EDITOR .env.remote      # PROJECT_NAME · APP_HOST · APP_PORT · VPS_SSH
./remote init            # create the docker context (once per project)
./remote up              # build on the VPS + deploy
```

→ live at `https://<APP_HOST>` with automatic HTTPS. 🎉

### Commands

| Command | Does |
|---|---|
| `./remote init` | Create the remote docker context for this project |
| `./remote up` | Build on the VPS + deploy |
| `./remote down` | Tear down + delete images & volumes on the VPS |
| `./remote stop` | Stop containers (keep images/volumes) |
| `./remote logs [svc]` | Follow logs |
| `./remote ps` | List running services |
| `./remote manage …` | Run `manage.py` (Django stack) |
| `./remote sh` | Shell into the app container |

## 🔧 Configuration — `.env.remote`

| Var | What it is |
|-----|------------|
| `PROJECT_NAME` | Namespaces containers, volumes & Traefik routers. Unique per project. |
| `APP_HOST` | Public host, e.g. `myapp.dev.yourdomain.com`. |
| `APP_PORT` | Port your app listens on inside the container. |
| `APP_SERVICE` | Primary service name (`app` generic · `django` for the Django stack). |
| `COMPOSE_FILE` | Which stack to run (see table above). |
| `APP_DOCKERFILE` | Path to your Dockerfile (generic stack). |
| `VPS_SSH` | `user@vps-ip` for the remote context. |
| `PROXY_NETWORK` · `CERT_RESOLVER` · `CERT_ENTRYPOINT` | Traefik/Coolify wiring (defaults: `coolify` · `letsencrypt` · `https`). |
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
<summary><b>Non-Docker-default projects</b></summary>

Point `APP_DOCKERFILE` at your Dockerfile and set `APP_PORT` to whatever it listens on.
For extra services, add them to `docker-compose.remote.yml`; give only web-facing ones the
`proxy` network + `traefik.*` labels (router rule = `Host(...)`, `loadbalancer.server.port` = your port).
</details>

---

<div align="center">
<sub>Build local · run remote · tear down clean.</sub>
</div>
