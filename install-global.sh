#!/usr/bin/env bash
# One-time global install of the `rdk` CLI. Then `rdk` works in any project folder.
#   curl -fsSL https://raw.githubusercontent.com/Enochthedev/remote-dev-kit/main/install-global.sh | bash
set -euo pipefail

REPO="${REMOTE_KIT_REPO:-Enochthedev/remote-dev-kit}"
BRANCH="${REMOTE_KIT_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
RDK_HOME="${RDK_HOME:-$HOME/.remote-dev-kit}"

echo "📦 Installing rdk into ${RDK_HOME} …"
mkdir -p "$RDK_HOME/stacks" "$RDK_HOME/bin"
for f in \
  "stacks/docker-compose.remote.yml" \
  "stacks/docker-compose.django.yml" \
  "stacks/traefik.yml" \
  "bin/rdk"; do
  curl -fsSL "${RAW}/${f}" -o "${RDK_HOME}/${f}"
done
chmod +x "$RDK_HOME/bin/rdk"

# Put `rdk` on PATH.
LINK=""
for d in "/usr/local/bin" "$HOME/.local/bin" "$HOME/bin"; do
  if [ -d "$d" ] && [ -w "$d" ]; then LINK="$d"; break; fi
done
if [ -n "$LINK" ]; then
  ln -sf "$RDK_HOME/bin/rdk" "$LINK/rdk"
  echo "🔗 linked: $LINK/rdk"
else
  echo "⚠️  add this to your shell profile:"
  echo "    export PATH=\"$RDK_HOME/bin:\$PATH\""
fi

echo ""
echo "✅ Installed. In any project:"
echo "   rdk init        # writes .env.remote (the only per-project file)"
echo "   rdk connect     # create the docker context"
echo "   rdk up          # build on the VPS + deploy"
