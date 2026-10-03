# CLI reference

Run `rdk` inside any project folder. The folder you run it in **is** the build context —
so to deploy one service out of a monorepo, `cd` into that service and run `rdk` there.

## Commands

| Command | What it does |
|---|---|
| `rdk setup` | **Once per machine:** save VPS, proxy, ACME email + base domain to `~/.config/rdk/config`. SSHes in and auto-detects the proxy network. Every project inherits these. |
| `rdk init [--db postgres]` | Scaffold `.env.remote` — the only per-project file. Auto-ignores it. With `--db postgres`, picks the Postgres+Redis stack and scaffolds `.env.remote.db`/`.env.remote.app` with a generated password and a ready-made `DATABASE_URL`. |
| `rdk config` | Show the effective merged config for this folder — each value marked `(project)`, `(global)` or `(built-in default)`. |
| `rdk stack explain` | What the selected stack actually runs: services, the env vars it reads (required vs default), data volumes, and how the app reaches Postgres/Redis. |
| `rdk connect` | Create the Docker context pointing at your VPS. Once per project. Warns if your `PROXY_NETWORK` doesn't exist on the box (and names the one that does). |
| `rdk proxy up` | **Bare VPS only:** start the kit's Traefik. Once per *server*, not per project. |
| `rdk up` | Build on the VPS and deploy. This is the one you'll type most. |
| `rdk watch` | Deploy, then live-sync your edits into the container (hot reload). |
| `rdk logs [service]` | Follow logs. |
| `rdk ps` | List **this project's** services. |
| `rdk vps` | List **everything** on the VPS — every project, not just yours. |
| `rdk sh` | Shell into the app container. |
| `rdk manage <cmd>` | Run `manage.py <cmd>` (Django stack). |
| `rdk stop` | Stop containers, keep images and volumes. |
| `rdk down` | Destroy: containers, images **and volumes**. Data is gone. |
| `rdk doctor` | Check prerequisites — docker CLI, SSH, context. |
| `rdk audit` | Security audit of the live deployment: TLS, headers, debug pages, exposed ports. |

`stop` keeps your data. `down` does not. That's the whole difference.

## Seeing what else is on the box

A VPS is rarely yours alone — other projects, a Coolify install, somebody's Postgres. `rdk vps`
lists **every** container on the server with the public URL each one answers on, and marks
yours with a `*`:

```text
🛰  running on root@203.0.113.10
   PROJECT           CONTAINER              STATE     URL
   coolify-proxy     coolify-proxy          running   https://traefik.example.com
 * honeybyte         honeybyte-django-1     running   https://honeybyte.dev.example.com
 * honeybyte         honeybyte-postgres-1   running
   ise-api           ise-api-app-1          running   https://ise-api.dev.example.com
   (* = this project)
```

Use it before you deploy, to see which hostnames and ports are already taken — and after,
when something you *thought* you tore down is still holding a port.

## `.env.remote`

The one file `rdk` adds to your repo. `rdk init` writes it and adds it to your ignore file,
because it holds your VPS address.

| Var | What it is |
|---|---|
| `PROJECT_NAME` | **The isolation key.** Namespaces containers, volumes and Traefik routers. A unique name = a completely separate deployment. |
| `APP_HOST` | Public host, e.g. `myapp.dev.yourdomain.com`. |
| `APP_PORT` | The port your app listens on *inside* the container. |
| `APP_SERVICE` | Primary service name. **Leave it unset** — it follows `COMPOSE_FILE` automatically (`django` for the Django stack, `app` otherwise). Only set it if you renamed the service. |
| `COMPOSE_FILE` | Which stack to run. See below. |
| `APP_DOCKERFILE` | Path to your Dockerfile (generic stack). |
| `VPS_SSH` | `user@vps-ip`. Must be passwordless. |
| `PROXY_NETWORK` | `web` (kit's own Traefik) or `coolify` (an existing proxy). |
| `ACME_EMAIL` | Let's Encrypt contact. Bare-VPS mode only. |
| `CERT_RESOLVER` / `CERT_ENTRYPOINT` | Traefik resolver/entrypoint names. Defaults: `letsencrypt` / `https`. |
| `MAIL_HOST` / `FLOWER_HOST` / `*_ENV_FILE` / `*_DOCKERFILE` | Django-stack extras. |

## Stacks

Pick one with `COMPOSE_FILE`:

| Value | Runs | Use for |
|---|---|---|
| `docker-compose.remote.yml` *(default)* | one web service from your `./Dockerfile` | **anything** — Node, Go, Rust, PHP, static |
| `docker-compose.django.yml` | django · postgres · redis · mailpit · celery · flower | Cookiecutter-Django backends |

Need a database in the generic stack? Add the service to `docker-compose.remote.yml` on the
`default` network. Only **web-facing** services need the `proxy` network and the `traefik.*`
labels.

## Proxy modes

| Your VPS | Set | Extra step |
|---|---|---|
| Bare (just Docker) | `PROXY_NETWORK=web` + `ACME_EMAIL` | `rdk proxy up`, once per server |
| Already runs Coolify / Traefik | `PROXY_NETWORK=coolify` | none — **skip** the proxy step |

You cannot run two things on ports 80/443. If the box already has a proxy, join it.

## Security

`rdk audit` checks a *live* deployment for the things that actually bite: TLS and HSTS,
security headers, an exposed debug page, ports open to the world.

The kit itself is written to be safe to read: it never `source`s or `eval`s your
`.env.remote` (a strict `KEY=VALUE` parser with a denylist for `PATH`, `LD_*` and friends),
and `rdk init` ignores your secrets file for you. See [SECURITY.md](../SECURITY.md).
