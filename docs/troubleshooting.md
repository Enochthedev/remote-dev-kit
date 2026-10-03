# Troubleshooting

The failures people actually hit, and why they happen. Most of them look like a broken tool
and are really a network or a DNS record.

## The app can't reach its database — "auth failed for user …"

**Symptom:** Postgres exists, credentials are right, and the app still can't authenticate.

**Cause:** you're on `PROXY_NETWORK=coolify`. Your app container joins Coolify's shared
network to reach its Traefik — and *Coolify's own* Postgres and Redis are on that same
network, aliased as `postgres` and `redis`. So `DATABASE_URL=postgres://…@postgres:5432/…`
resolves to **Coolify's database**, not yours, and the credentials are wrong because it's
somebody else's DB.

Docker network `priority` does **not** fix the resolution order. Don't bother trying.

**Fix:** the Django stack gives your services unique aliases. Point your app at those:

```bash
DATABASE_URL=postgres://user:pass@${PROJECT_NAME}-postgres:5432/dbname
REDIS_URL=redis://${PROJECT_NAME}-redis:6379/0
```

Bare-VPS mode (`PROXY_NETWORK=web`) has no such collision — the kit's own network has no
other databases on it.

## No certificate / the site won't load over HTTPS

Your wildcard DNS record is **proxied**. Set it to **DNS only** (grey cloud on Cloudflare).

Let's Encrypt validates over HTTP-01, which means it has to reach *your* Traefik. Behind a
proxy it reaches the proxy instead, the challenge fails, and no certificate is ever issued.

## Django returns 400 — DisallowedHost

Django only answers on hosts it knows about, and it doesn't know about your new subdomain.

Make it read the host from the environment:

```python
ALLOWED_HOSTS += env.list("DJANGO_ALLOWED_HOSTS", default=[])
CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=[])
```

Then set `DJANGO_ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS` in your app's env file.

⚠️ **Never run `DEBUG=True` on a public host.** It publishes your settings, your
environment, and a stack trace with source to anyone who finds a 500. Run `rdk audit` — it
checks for exactly this.

## The VPS build fails on dependencies your Mac installs fine (pnpm/npm)

The VPS builds from a clean image — none of your Mac's toolchain state comes along. Two
things bite in practice:

- **Pin your package manager** in `package.json`, e.g. `"packageManager": "pnpm@10.7.1"`,
  and use `corepack enable` in the Dockerfile. Otherwise the image picks whatever's
  current — pnpm 11's minimum-release-age guard, for example, rejects freshly-published
  dependency versions that installed fine locally the day before.
- **Commit your lockfile** and install with `pnpm install --frozen-lockfile` (or
  `npm ci`). Reproducible on the VPS means the same resolution you tested locally.

## The build dies with "connection reset by peer"

Long builds stream over SSH, and an idle-looking connection gets dropped.

Add keepalives to the VPS entry in `~/.ssh/config`:

```ssh-config
Host your-vps
    HostName YOUR_VPS_IP
    ServerAliveInterval 15
    ServerAliveCountMax 8
    TCPKeepAlive yes
```

## `ssh-copy-id` says the key is already installed — but auth still fails

It's lying to you, sort of. `ssh-copy-id` offers **every key in your agent** at once. If
*any* of them authenticates, it reports success — even if the specific key you meant to
install isn't on the box at all.

Test with the agent and your SSH config out of the picture:

```bash
ssh -F /dev/null -o IdentitiesOnly=yes -i ~/.ssh/the_key_you_mean you@YOUR_VPS_IP 'echo ok'
```

That tells you the truth about which key actually works.

## Port 80/443 already in use

Something already owns the ports — usually Coolify, or a Traefik you started earlier.

Don't start a second one. Set `PROXY_NETWORK=coolify` and skip `rdk proxy up`.

## My CMS / feature isn't there

The deployed image contains **only the branch you built from**. If the feature lives on
another branch, the running app has never seen it.

```bash
git checkout the-branch-with-the-thing
rdk up
```

## Changes aren't showing up

- Using `rdk up`? It rebuilds — but the *browser* may be caching. Hard-refresh.
- Using `rdk watch`? Web processes hot-reload; **background workers don't**. Celery and
  friends need an `rdk up` to pick up new code.

## Start here when it's none of the above

```bash
rdk doctor      # docker CLI, SSH reachability, context
rdk logs        # what the app itself says
rdk ps          # is it even running?
```
