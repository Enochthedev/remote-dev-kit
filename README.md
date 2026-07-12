<!-- LOGO: placeholder — swap the 🛰️ below for the custom mark when it exists. -->

# 🛰️ rdk

**Run your Docker projects on a VPS, not your Mac.** Your code stays on your laptop, the build and the containers happen on the server, and every project gets its own HTTPS subdomain.

```bash
curl -fsSL https://raw.githubusercontent.com/Enochthedev/remote-dev-kit/main/install-global.sh | bash
```

<!-- DEMO: vhs tape at .github/demo.tape, output demo.gif -->
<!-- Uncomment once demo.gif is generated — until then this would render as a broken image.
![rdk in action](demo.gif)
-->

## Quickstart

You need passwordless SSH to a VPS that has Docker, and one wildcard DNS record. Set both up once, and every project afterwards is three commands.

**1 ▸ SSH key.** The remote Docker context needs key auth, not a password:

```bash
ssh-keygen -t ed25519 -C "rdk"        # skip if you already have a key
ssh-copy-id youruser@YOUR_VPS_IP
ssh youruser@YOUR_VPS_IP 'echo ok'    # must print "ok" without prompting
```

**2 ▸ Wildcard DNS.** One record covers every project you will ever deploy:

| Type | Name    | Content       | Proxy        |
|------|---------|---------------|--------------|
| A    | `*.dev` | `YOUR_VPS_IP` | **DNS only** |

> Keep it **DNS only** (grey cloud on Cloudflare). Traefik answers Let's Encrypt's HTTP challenge itself, and a proxied record breaks it. `*.dev` sits safely alongside a production `*` record — it is a more specific, separate name.

**3 ▸ Deploy.** In any project with a `Dockerfile`:

```bash
cd ~/Code/your-project
rdk init          # writes .env.remote — edit APP_HOST, VPS_SSH, APP_PORT
rdk connect       # creates the docker context for this project (once)
rdk up            # builds on the VPS and starts it
```

→ live at `https://<APP_HOST>`, with a certificate.

On a **bare VPS** — one with Docker but no existing proxy — run `rdk proxy up` once per server before your first deploy. It starts the Traefik that terminates TLS. If your VPS already runs Coolify or another Traefik, set `PROXY_NETWORK=coolify` in `.env.remote` and skip that step.

Check your work at any point:

```console
$ rdk doctor
🩺 RDK doctor — myapp
  ✔ docker CLI installed
  ✔ passwordless SSH to youruser@YOUR_VPS_IP
  ✔ docker context 'remote-myapp' exists
  ✔ stack 'docker-compose.django.yml' found
  ✔ APP_HOST=myapp.dev.yourdomain.com
── 0 failed, 0 warnings ──
```

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

Your `docker` CLI points at the VPS through a **remote context**, so the build runs *there* and nothing lands on your Mac — no images, no layer cache, no daemon. You can quit Docker Desktop or OrbStack entirely; the CLI alone is enough.

Your app is **baked into the image**, not bind-mounted, so no editable copy of your source persists on the server. `rdk down` deletes the images and volumes, and it is gone.

RDK writes exactly one file into your repo: **`.env.remote`**, holding that project's config and its SSH target. `rdk init` adds it to `.gitignore` for you, and `rdk audit` warns you if it ever isn't.

## Requirements

- A **VPS with Docker** and **SSH access**. That is the only hard requirement.
- A **domain** with a wildcard `*.dev` record pointing at it.
- The **`docker` CLI** on your Mac — no daemon needed: `brew install docker`.

## How it compares

RDK is a development tool. Kamal, Coolify and Dokploy are production deployment platforms. They overlap enough to be mistaken for one another, so here is the honest split.

| | **rdk** | **Kamal** | **Coolify** | **Dokploy** |
|---|---|---|---|---|
| Interface | CLI + VS Code extension | CLI | Web dashboard | Web dashboard |
| Installed on the server | nothing — Docker + SSH (plus Traefik in bare mode) | Docker + `kamal-proxy` | the full platform | the full platform |
| Reverse proxy | Traefik | `kamal-proxy` | Traefik (default; Caddy optional) | Traefik |
| Zero-downtime deploys | ○ | ● | — | — |
| Managed databases | ○ you declare them in compose | ● accessories | ● | ● |
| Automated backups | ○ | — | ● | ● |
| Git-push deploys | ○ | — | ● | ● |
| Hot-reload local edits into the running container | ● `rdk watch` | — | — | — |
| Built for | dev and preview environments | production | production | production |

● documented · ○ deliberately not supported · — not documented, so not claimed here

**Where RDK is behind, plainly.** There is no web UI, no zero-downtime rollout (`rdk up` recreates containers, so expect a few seconds of downtime), no managed databases or backups, no git-push or CI-triggered deploys, no multi-server support, no rollbacks, and no team accounts. If you are shipping to real users, use one of the other three. Even Kamal — the closest in spirit — notes that its accessories "are not updated when you deploy, and they do not have zero-downtime deployments," so for stateful services none of this comes free.

**What RDK does that they don't.** Nothing is installed on your server, and `rdk watch` syncs your local edits straight into the running remote container. That is a dev loop, not a deployment pipeline.

## Iterating

**Deploy new code** — run it again. Docker's layer cache makes the rebuild fast:

```bash
rdk up            # → new version, same URL
```

**Hot reload** — sync edits live instead of redeploying:

```bash
rdk watch         # streams changed files into the running container
```

`watch` uses `docker compose watch`. Your dev server — Django's `runserver`, `uvicorn --reload`, Vite, nodemon — picks the change up instantly. The sync goes into the ephemeral container, so your code still never persists on the VPS.

⚠ Only the web process hot-reloads. Background workers such as Celery pick changes up on their next `rdk up`.

**Test another branch** — the running app contains only the branch you built from:

```bash
git checkout feat/some-feature
rdk up            # same URL, now running that branch
```

**See what else is on the box** before you claim a subdomain:

```console
$ rdk vps
🛰  running on youruser@YOUR_VPS_IP
   PROJECT       CONTAINER            STATE     URL
 * myapp         myapp-django-1       running   https://myapp.dev.yourdomain.com
   myapp         myapp-postgres-1     running
   other-thing   other-thing-web-1    running   https://other.dev.yourdomain.com
   (* = this project)
```

## Stacks

Pick one with `COMPOSE_FILE` in `.env.remote`:

| `COMPOSE_FILE` | Runs | Use for |
|---|---|---|
| **`docker-compose.remote.yml`** *(default)* | one web service from your `./Dockerfile` | **any** language or framework |
| `docker-compose.remote-db.yml` | the same, plus postgres · redis | apps that need a database |
| `docker-compose.django.yml` | django · postgres · redis · mailpit · celery · flower | Cookiecutter-Django backends |

Only the web service is public. Postgres and Redis stay on the internal network, reachable from your app at `${PROJECT_NAME}-postgres` and `${PROJECT_NAME}-redis`.

> Those aliases matter. On a shared proxy network — Coolify's, for instance — there is usually already a container called `postgres`, and an unaliased one would collide with it. Point your app's `DB_HOST` / `REDIS_HOST` at the aliased names.

⚠ `docker-compose.remote-db.yml` requires `REDIS_PASSWORD` in `.env.remote`. Redis will not start without it.

## Commands

| Command | Does |
|---|---|
| `rdk init` | Write `.env.remote` — the only per-project file |
| `rdk connect` | Create this project's remote docker context (once) |
| `rdk proxy up` | Bare VPS: start Traefik (once per server) |
| `rdk up` | Build on the VPS and deploy |
| `rdk watch` | Deploy, then live-sync your edits (hot reload) |
| `rdk stop` | Stop the containers, keep images and volumes |
| `rdk down` | Destroy — deletes images **and volumes** |
| `rdk logs [svc]` | Follow logs |
| `rdk ps` | List this project's services |
| `rdk vps` | List everything running on the VPS, across all projects |
| `rdk sh` | Shell into the app container |
| `rdk manage …` | Run `manage.py` (Django stack) |
| `rdk doctor` | Check prerequisites — docker, SSH, context, stack |
| `rdk audit` | Security audit of the live deployment |

<details>
<summary><b>Prefer not to install anything globally?</b></summary>

The per-project installer vendors the stacks and a `./remote` script into the repo:

```bash
cd ~/Code/your-project
curl -fsSL https://raw.githubusercontent.com/Enochthedev/remote-dev-kit/main/install.sh | bash
```

The commands are identical — `./remote up`, `./remote watch`, and so on — except that `./remote init` does what `rdk connect` does. It also drops `.vscode/tasks.json`, so **⇧⌘P → Run Task** gives you `remote: watch / up / logs / ps / down`.

`rdk doctor`, `rdk audit` and `rdk vps` are global-CLI only.
</details>

## Configuration — `.env.remote`

| Var | What it is |
|-----|------------|
| `PROJECT_NAME` | Namespaces containers, volumes and Traefik routers. Unique per project. |
| `APP_HOST` | Public host, e.g. `myapp.dev.yourdomain.com`. |
| `APP_PORT` | The port your app listens on inside the container. |
| `APP_SERVICE` | Primary service name — `app` generic, `django` for the Django stack. |
| `COMPOSE_FILE` | Which stack to run (see above). |
| `APP_DOCKERFILE` | Path to your Dockerfile (generic stack). |
| `VPS_SSH` | `user@vps-ip`, for the remote context. |
| `PROXY_NETWORK` | `web` for RDK's own Traefik, `coolify` for an existing proxy. |
| `ACME_EMAIL` | Let's Encrypt contact. Bare-VPS mode only. |
| `CERT_RESOLVER` · `CERT_ENTRYPOINT` | Traefik resolver and entrypoint names. Default `letsencrypt` · `https`. |
| `REDIS_PASSWORD` | **Required** by the `remote-db` stack. Redis will not start without it. |
| `APP_ENV_FILE` · `DB_ENV_FILE` | Env files for your app and for Postgres (`POSTGRES_USER` / `_PASSWORD` / `_DB`). |
| `POSTGRES_IMAGE` · `REDIS_IMAGE` | Override the images — postgis, pgvector, a pinned Redis. |
| `MAIL_HOST` · `FLOWER_HOST` · `*_DOCKERFILE` | Django-stack extras. |

<details>
<summary><b>Django</b></summary>

Let the app accept its new host:

```python
ALLOWED_HOSTS += env.list("DJANGO_ALLOWED_HOSTS", default=[])
CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=[])
```

Set `DJANGO_ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS` in your app env file.

⚠ Never run `DEBUG=True` on a public host. `rdk audit` flags a leaked debug page as a failure.
</details>

<details>
<summary><b>Other stacks</b></summary>

Point `APP_DOCKERFILE` at your Dockerfile and set `APP_PORT` to whatever it listens on. That is all the generic stack needs — Node, Go, Rust, PHP, static, anything.

For extra services, add them to `docker-compose.remote.yml`. Give only the web-facing ones the `proxy` network and the `traefik.*` labels: the router rule is `Host(...)`, and `loadbalancer.server.port` is your port.
</details>

## Docs

| | |
|---|---|
| [Getting started](docs/getting-started.md) | Nothing to a live HTTPS URL. Start here. |
| [CLI reference](docs/cli.md) | Every command, every `.env.remote` key, the stacks. |
| [VS Code extension](docs/vscode.md) | The same thing without the terminal. |
| [Troubleshooting](docs/troubleshooting.md) | Read this when something breaks. |

## Security

RDK holds an SSH key to your server and reads a config file out of whatever repo you run it in, so it is worth knowing what it does and doesn't do. It **parses** `.env.remote` rather than sourcing it, so a hostile repo cannot run code on your Mac. It refuses config keys like `PATH` and `LD_PRELOAD`. It publishes no host ports, so your database stays behind the proxy.

`rdk audit` checks the live deployment: TLS, the HTTP→HTTPS redirect, security headers, leaked debug pages, exposed ports, and whether `.env.remote` is gitignored.

The full threat model and audit findings — including the two risks that are accepted rather than fixed — are in [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).

---

<sub>Build local · run remote · tear down clean.</sub>
