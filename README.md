# remote-dev-kit

Run and test your Docker projects on a **remote VPS** instead of your Mac — so Docker
never eats local disk/RAM — while your **code stays only on your machine**.

You build from your laptop, the image is built + run on the VPS, and each project is
auto-served at `https://<project>.dev.yourdomain.com` with automatic HTTPS. Tear it
down and it's completely gone from the VPS.

Built for the remote-Docker-context + Traefik pattern (works great alongside Coolify).
The default compose assumes a **Cookiecutter-Django** backend, but any stack works if
you swap the `services:` block.

---

## How it works

```
Your Mac (code + docker CLI)                    VPS (Docker daemon + Traefik)
  ./remote up  ──build context over SSH──▶  builds image, runs containers
                                            Traefik routes <project>.dev.<domain> + TLS
```

- `docker context` points your CLI at the VPS — the build happens **there**, nothing
  is stored on your Mac (you can quit/uninstall Docker Desktop / OrbStack).
- The app is **baked into the image** (no bind-mount), so no editable source folder
  lives on the VPS. `./remote down` deletes image + volumes → clean.
- Traefik labels put each service on a subdomain; Let's Encrypt certs are automatic.

---

## One-time setup (do this once, ever)

1. **A VPS running a Traefik-based proxy** (e.g. Coolify). Note two values:
   ```bash
   docker network ls | grep coolify                                # proxy network name
   docker inspect coolify-proxy 2>/dev/null | grep -i certresolver # cert resolver name
   ```
2. **A scoped wildcard DNS record** at your DNS provider — set once, covers every project:

   | Type | Name   | Content        | Proxy        |
   |------|--------|----------------|--------------|
   | A    | `*.dev`| `<VPS IP>`     | DNS only     |

   Now `anything.dev.yourdomain.com` resolves to the VPS with **no per-project DNS**.
   Use *DNS only* (grey cloud on Cloudflare) so Traefik can issue certs via HTTP-01.
3. **Docker CLI on your Mac** (just the CLI — no local daemon needed):
   `brew install docker`.

---

## Per-project usage

From your project root:

```bash
# install the kit into this project
curl -fsSL https://raw.githubusercontent.com/Enochthedev/remote-dev-kit/main/install.sh | bash

# edit the one config file
$EDITOR .env.remote        # PROJECT_NAME, APP_HOST, VPS_SSH, ...

./remote init              # create the docker context (once per project)
./remote up                # build on the VPS + deploy
```

Your app is now live at the `APP_HOST` you set. Common commands:

```bash
./remote manage migrate    # run manage.py inside the container
./remote logs django       # follow logs
./remote ps                # what's running
./remote down              # wipe it from the VPS (images + volumes gone)
```

---

## Configuration (`.env.remote`)

| Var | What it is |
|-----|------------|
| `PROJECT_NAME` | Namespaces containers/volumes + Traefik routers. Unique per project. |
| `APP_HOST` | Public host for the app, e.g. `myapp.dev.yourdomain.com`. |
| `APP_PORT` | Port your app listens on inside the container (Django: `8000`). |
| `MAIL_HOST` / `FLOWER_HOST` | Hosts for Mailpit / Flower UIs. |
| `VPS_SSH` | `user@vps-ip` — where the remote docker context connects. |
| `PROXY_NETWORK` | Your Traefik proxy network (Coolify default: `coolify`). |
| `CERT_RESOLVER` | Traefik cert resolver (Coolify default: `letsencrypt`). |
| `CERT_ENTRYPOINT` | Traefik HTTPS entrypoint (default: `https`). |
| `APP_DOCKERFILE` / `*_ENV_FILE` | Build inputs — override if your repo layout differs. |

### Django note
For the app to accept its new host, add to your Django settings (env-driven):

```python
ALLOWED_HOSTS += env.list("DJANGO_ALLOWED_HOSTS", default=[])
CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=[])
```
and set `DJANGO_ALLOWED_HOSTS` / `CSRF_TRUSTED_ORIGINS` in your app env file.
⚠️ Don't run with `DEBUG=True` on a public host.

---

## Non-Django projects
Replace the `services:` block in `docker-compose.remote.yml` with your own services.
Keep the pattern: attach web services to the `proxy` network and give them the
`traefik.*` labels (router rule = `Host(...)`, `loadbalancer.server.port` = your port).
