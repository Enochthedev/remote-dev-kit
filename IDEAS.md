# RDK — ideas not yet built

Scratchpad. Nothing here is implemented; it's what came up while using the tool.

---

## Doppler (or any secret manager) as the source of env

**Today:** `.env.remote`, `.env.remote.app` and `.env.remote.db` are plain local
files, gitignored, edited by hand. Whatever is on the machine that runs `rdk up`
is what gets deployed.

**The problem with that**

- The files exist on one laptop. Nobody else can deploy, and if the laptop dies
  the deployed config is only recoverable by reading it off the VPS.
- Nothing says whether the local copy still matches what's running. `ise-api`'s
  `.env.remote.app` carries a "Generated from Doppler (config: dev)" header from
  a one-off export, and it has since drifted from it — which is exactly the
  failure this describes.
- Real credentials sit in plaintext in the project folder. `ise-api`'s holds a
  live Brevo API key and a Firebase private key.
- Editing a value means editing a file and remembering to redeploy. There is no
  record of what changed or when.

**Rough shape of a fix**

Let `.env.remote` name a source instead of holding values:

```
ENV_SOURCE=doppler
DOPPLER_PROJECT=api
DOPPLER_CONFIG=dev
```

`rdk up` would then resolve secrets at deploy time — `doppler secrets download
--no-file --format env` — and hand them to compose without ever writing them to
disk. Local files stay supported as the default and the offline fallback.

Worth keeping generic: `ENV_SOURCE=file|doppler|1password|sops`. The idea is
"where do secrets come from", not "Doppler specifically".

**Also worth having**

- `rdk env diff` — what is in the source vs what the running container actually
  has. The commonest deploy confusion is a value someone believes they changed.
- `rdk env pull` — materialise a local file from the source for offline work.

**Related, already half-done:** the generic stack now declares build `args:` for
`NEXT_PUBLIC_*` / `VITE_*`, because those are baked into the bundle at build time
and a runtime secret manager can't help with them. Any env-source work needs to
keep that distinction — build-time values and runtime values are different
problems.

---

## The CLI and the VSCode extension ship separate copies of `stacks/`

Found 2026-08-09: `remote-dev-kit/stacks/` and `remote-dev-kit-vscode/stacks/`
are independent files, and the two had already drifted. A fix applied to one is
invisible to the other, and which one runs depends on whether the user typed
`rdk` or clicked the extension — the same project can then build differently for
the same person on the same machine.

The build-args change had to be made in three places to actually take effect:
both source repos and the installed extension under
`~/.vscode-insiders/extensions/`.

Worth making `stacks/` a single shared source — a submodule, a workspace
package, or a build step that copies the CLI's into the extension at package
time — so there is one definition and no chance of divergence.
