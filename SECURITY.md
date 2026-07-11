# RDK — Security

RDK drives Docker on a remote VPS over SSH. It handles an SSH target, runs shell
commands, and (in bare-VPS mode) a proxy that talks to the Docker socket. This doc is the
security audit of RDK's own code + the threat model.

## Threat model

- **You run `rdk` inside project folders**, some of which you may not fully trust (cloned
  repos, teammates' branches). A repo must not be able to compromise your Mac.
- **`.env.remote` holds sensitive config** (SSH target, and via env files, app secrets).
- **The remote context executes on your VPS** over your SSH key.

## Audit findings

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | `rdk` sourced `.env.remote`, so a crafted config could **run code on your Mac** on `rdk up` | High | **Fixed** — replaced `source` with a non-executing `KEY=VALUE` parser |
| 2 | Even parsed, a config could set `PATH`/`LD_PRELOAD`/etc. to **hijack later commands** | High | **Fixed** — loader denies `PATH IFS ENV BASH_ENV SHELLOPTS PS4 PROMPT_COMMAND LD_* DYLD_* BASH_FUNC_*` |
| 3 | `.env.remote` (SSH target + creds) could be **committed** | Medium | **Fixed** — `rdk init` auto-adds it to `.gitignore`; `rdk audit` warns if not ignored |
| 4 | VS Code extension wrote env files from settings; a newline could **inject extra vars** | Low | **Fixed** — values are newline-stripped |
| 5 | Bare-VPS Traefik mounts the Docker socket | Accepted | **Documented** — read-only, required by Traefik's Docker provider, only in `bare` mode, on your own VPS |
| 6 | `curl \| bash` install | Accepted | **Documented** — standard; review the script or pin a commit if you prefer |

## Hardening in place

- **No `eval`, no `source` of untrusted files.** Config is parsed, not executed.
- **All shell interpolation is quoted.** The CLI runs Docker via argv arrays; the extension
  single-quote-escapes every interpolated value before sending to a terminal.
- **SSH:** RDK stores no passwords. It uses your `~/.ssh/config` + `known_hosts` (host-key
  verification) and key auth. The docker context is just `host=ssh://user@host`.
- **No host-published ports.** App/DB/cache are reachable only through the proxy; `rdk audit`
  flags any `0.0.0.0:` port bindings.

## `rdk audit` (deployment posture)

`rdk audit` checks a live deployment, not just the code:
- valid TLS certificate; HTTP→HTTPS redirect
- security headers (HSTS, `X-Content-Type-Options`, `X-Frame-Options`/CSP)
- **debug-page exposure** (leaked stack traces / `DEBUG=True`)
- no host-published ports (DB/cache stay private)
- `.env.remote` is gitignored

## Reporting

Found something? Open an issue at
<https://github.com/Enochthedev/remote-dev-kit/issues> (please don't include secrets).
