# RFC-001 — Overlay stacks, MCP server, TTL deployments

Status: **proposed**
Scope: `remote-dev-kit` (CLI + stacks) and `remote-dev-kit-vscode` (extension)

Three changes. The first is a rewrite of how RDK composes a deployment; the other two are
features that only become clean once it lands.

---

## 1. Overlay, not fork

### The problem

RDK ships a compose file per stack (`docker-compose.django.yml`, `docker-compose.remote-db.yml`, …)
and owns the whole service graph. That is a fork of the user's own compose file.

Measured, not asserted:

| | services |
|---|---|
| `honeybyte/docker-compose.local.yml` | django · postgres · redis · mailpit · celeryworker · celerybeat · flower |
| `rdk/stacks/docker-compose.django.yml` | django · postgres · redis · mailpit · celeryworker · celerybeat · flower |

The same seven services, defined twice, in two repositories. When cookiecutter-django changes,
RDK's copy rots and nobody notices until a deploy behaves differently from local.

It also doesn't scale. "Support every setup" on this design means shipping a stack per
combination — Rails+Postgres, Next+Redis, Laravel+MySQL, Phoenix, Go+Mongo — and maintaining
other people's compose files indefinitely. Meanwhile RDK **ignores** the `docker-compose.yml`
that most real projects already have. `ise-api` has one. RDK reads none of it.

### The design

RDK stops owning services. It owns only the two things that are actually its business:
**the proxy network** and **the Traefik labels on the one web-facing service**.

Your compose file is the base. RDK layers an overlay on top:

```
docker --context remote-<proj> compose \
  -p <PROJECT_NAME> --project-directory <root> --env-file .env.remote \
  -f <BASE_COMPOSE> \
  -f <rendered overlay> \
  up -d --build
```

The overlay, in full:

```yaml
networks:
  proxy:
    external: true
    name: ${PROXY_NETWORK:-coolify}

services:
  <APP_SERVICE>:                 # rendered — see constraint below
    networks: [default, proxy]
    labels:
      - traefik.enable=true
      - traefik.docker.network=${PROXY_NETWORK:-coolify}
      - traefik.http.routers.${PROJECT_NAME}-web.rule=Host(`${APP_HOST}`)
      - traefik.http.routers.${PROJECT_NAME}-web.entrypoints=${CERT_ENTRYPOINT:-https}
      - traefik.http.routers.${PROJECT_NAME}-web.tls.certresolver=${CERT_RESOLVER:-letsencrypt}
      - traefik.http.services.${PROJECT_NAME}-web.loadbalancer.server.port=${APP_PORT:-8000}
```

That's the whole thing. Every language, every framework, every service topology — because RDK
no longer needs to know any of them.

### Two constraints, both verified against honeybyte

**Compose forbids variable interpolation in service keys.** `${APP_SERVICE}:` is rejected:

```
services additional properties '${APP_SERVICE:-django}' not allowed
```

So the overlay cannot be a static shipped file. RDK must **render** it at deploy time,
substituting the real service name, and write it to a temp path
(`$XDG_CACHE_HOME/rdk/<project>/overlay.yml`). Cheap, but it's a build step, not an asset.

**Compose merge is additive, which is what makes this work.** Merging the overlay onto
honeybyte's real `docker-compose.local.yml`:

```
django networks: [ default, proxy ]     ← default preserved, proxy added
traefik labels : 6
proxy net      : external=true name=coolify
other services : celerybeat celeryworker flower mailpit postgres redis   (untouched)
```

The base file's own networks and labels survive. If merge had been replace-semantics, the
model would be dead; it isn't.

### Base-file detection

New `.env.remote` key, auto-detected on `rdk init`:

```
BASE_COMPOSE=docker-compose.local.yml
```

Detection order: `BASE_COMPOSE` if set → `compose.yaml` / `compose.yml` /
`docker-compose.yml` / `docker-compose.yaml` → cookiecutter's `docker-compose.local.yml` →
none. Multiple base files allowed (comma-separated, passed as repeated `-f`).

**When there is no base compose file**, RDK falls back to today's behaviour: it synthesises a
one-service stack from `APP_DOCKERFILE`. That's the honest role for the bundled stacks — a
scaffold for projects that have no compose of their own, not a fork of ones that do.

### Hot reload

`develop.watch` moves into the overlay too, but only if the base file doesn't already define
it — never clobber an author's own sync rules.

### Migration

- `COMPOSE_FILE` keeps working. If set to a bundled stack, RDK runs it exactly as today.
- `rdk doctor` gains a check: *"this project has its own compose file but RDK is running a
  bundled stack — you probably want `BASE_COMPOSE`."*
- `docker-compose.django.yml` becomes **deprecated**, not deleted. It is the clearest instance
  of the fork problem; cookiecutter projects should overlay their own `docker-compose.local.yml`.
- `docker-compose.remote.yml` and `docker-compose.remote-db.yml` survive as scaffolds for the
  no-compose case.

---

## 2. `rdk mcp` — RDK as an MCP server

Expose RDK to agents so Claude Code can deploy and debug a VPS project without shell access.

### Transport and shape

A stdio MCP server: `rdk mcp`. Registered once:

```bash
claude mcp add rdk -- rdk mcp
```

Implemented in Node (the extension is already TypeScript, and the bash CLI can't reasonably
speak JSON-RPC). It is a **thin wrapper that shells out to `rdk`** — the bash CLI stays the
single engine, so there is no second implementation of the deploy logic to drift. This is the
same mistake we're fixing in part 1; don't repeat it inside our own repo.

### Tools

| Tool | Effect | Notes |
|---|---|---|
| `rdk_list` | read | Projects under a root — name, host, phase |
| `rdk_status` | read | Phase + per-service state for one project |
| `rdk_logs` | read | `tail` bounded (default 200, max 2000) |
| `rdk_vps` | read | Everything on the box, all projects |
| `rdk_doctor` | read | Prerequisite check |
| `rdk_audit` | read | TLS, headers, debug exposure, ports |
| `rdk_deploy` | **write** | Build on VPS + start |
| `rdk_stop` | **write** | Stop, keep volumes |
| `rdk_extend` | **write** | Push out the TTL (part 3) |
| `rdk_destroy` | **destructive** | Requires `confirm: true`; deletes volumes |

`rdk_watch` is deliberately absent — it is a long-lived foreground stream and does not fit a
request/response tool.

### Safety

Non-negotiable, because this hands an agent an SSH key to a live server:

- **Root allowlist.** The server only operates on directories under `RDK_MCP_ROOTS`
  (defaults to the cwd it was launched in). A project path outside that is refused.
- **`rdk_destroy` requires `confirm: true`** as an explicit argument, and names what it will
  delete in the error when omitted. No agent destroys a database by autocompleting.
- **Read tools are the default surface.** Write tools can be disabled entirely with
  `RDK_MCP_READONLY=1`, which is the right setting for anything running unattended.
- No arbitrary command execution. There is no `rdk_sh` and no `rdk_manage` — those are shells
  by another name.

---

## 3. TTL deployments

"Run for four hours, then shut down." The point is that a dev/preview box shouldn't quietly
accumulate twelve forgotten stacks.

### Where the timer lives

**On the VPS, not the Mac.** A client-side timer dies when the laptop sleeps, which is exactly
when you need it. Enforcement must survive a closed lid, a lost network, and a VPS reboot.

### Why not container labels

The obvious design — stamp `rdk.expires_at` as a container label and have a reaper read it —
has a fatal flaw: **Docker labels are immutable on a running container.** `rdk extend 2h`
would have to recreate the containers, i.e. restart your app to tell it to live longer. Absurd.

### State lives in a file on the VPS

RDK already holds passwordless SSH. Use it.

```
/var/lib/rdk/ttl/<project>      # a single line: <expiry epoch seconds>
```

- `rdk up --ttl 4h` computes expiry **using the VPS clock** (`ssh vps date +%s` + duration),
  not the Mac's, so clock skew can't kill a deployment early.
- `rdk extend 2h` rewrites that one file. No container is touched.
- `rdk ttl` prints remaining time. `rdk ttl off` removes the file.

### The reaper

One per VPS, alongside Traefik (`stacks/reaper.yml`, started by `rdk proxy up`):

```
every 60s:
  for each /var/lib/rdk/ttl/<project>:
    if now > expiry:
      docker compose -p <project> <TTL_ACTION>
      rm the ttl file
```

`TTL_ACTION` in `.env.remote`, default **`stop`** — containers down, **volumes kept**.
`destroy` is opt-in. The default must not be the one that deletes your database.

Scoping is strict: the reaper acts only on projects that have a TTL file **and** carry the
`com.docker.compose.project` label matching it. It must never touch Coolify's containers, which
share the box.

### Prompting

The reaper cannot prompt — it runs on a server you aren't looking at. So:

- **Enforcement is server-side and unconditional.** That's the feature.
- **Warning is client-side and best-effort.** With `TTL_PROMPT=10m`, the extension (and
  `rdk` when running interactively) notifies at T-10:
  *"ise-api expires in 10 minutes."* → `[Extend 1h] [Stop now] [Let it expire]`
- If your laptop is shut, you get no prompt and the deployment still stops. That is correct
  behaviour, not a gap.

### New `.env.remote` keys

```
TTL=4h                  # empty/absent = no expiry (today's behaviour)
TTL_ACTION=stop         # stop | destroy
TTL_PROMPT=10m          # client-side warning lead time; 0 disables
```

### Security cost — flag this loudly

The reaper needs to **stop containers**, so it needs the Docker socket **writable**. Today
RDK's Traefik mounts the socket **read-only**, and `SECURITY.md` documents that as an accepted
risk *precisely because it is read-only*. A writable socket is a genuine escalation: socket
write access is root on the host.

Options, in order of preference:

1. **A tiny reaper image we control**, socket-writable, doing nothing but the loop above.
   Smallest possible attack surface, but the escalation is real and must be re-documented in
   `SECURITY.md`.
2. **A `systemd` timer on the VPS** installed by `rdk proxy up`. No socket exposure at all,
   but it breaks RDK's "nothing is installed on your server" promise — which is the headline
   claim in the README's comparison table.
3. **Socket-proxy in front of the reaper** (e.g. `tecnativa/docker-socket-proxy`) allowing only
   `POST /containers/*/stop`. Best security, one more moving part.

**Recommendation: (3), falling back to (1).** Do not ship this without updating `SECURITY.md`.

---

## Phasing

1. **Overlay** — the foundation. Nothing else should be built on the forked-stack model.
2. **MCP** — small once the CLI is the single engine; it's a wrapper.
3. **TTL** — needs the reaper decision above settled first.

## Open questions

- Multiple web-facing services in one project (an API *and* a web UI in the same compose).
  Today `APP_SERVICE` + `APP_HOST` are singular. Overlay makes multi-host possible — is it worth
  the config surface? Proposal: defer.
- Should `rdk init` write `BASE_COMPOSE` automatically when it detects a compose file, or ask?
  Proposal: detect, write, and say so.
- Does the VS Code extension keep bundling stacks at all once overlay lands, or shell out to
  `rdk` like the MCP server does? Consolidating on one engine is tempting.
