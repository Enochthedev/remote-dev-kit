#!/usr/bin/env bash
# Drop the remote-dev-kit into the current project.
# Run from your project root:
#   curl -fsSL https://raw.githubusercontent.com/Enochthedev/remote-dev-kit/main/install.sh | bash
set -euo pipefail

REPO="${REMOTE_KIT_REPO:-Enochthedev/remote-dev-kit}"
BRANCH="${REMOTE_KIT_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

echo "📦 Installing remote-dev-kit from ${REPO}@${BRANCH} ..."
# src-in-repo : dest-in-your-project  (installed flat so the build context is your project root)
for pair in \
  "stacks/docker-compose.remote.yml:docker-compose.remote.yml" \
  "stacks/docker-compose.django.yml:docker-compose.django.yml" \
  ".env.remote.example:.env.remote.example" \
  "bin/remote:remote"; do
  curl -fsSL "${RAW}/${pair%%:*}" -o "${pair##*:}"
done
chmod +x remote
[ -f .env.remote ] || cp .env.remote.example .env.remote

# Keep the kit out of the project's tracked history (local-only).
if [ -d .git ]; then
  touch .git/info/exclude
  for f in docker-compose.remote.yml docker-compose.django.yml .env.remote.example .env.remote remote; do
    grep -qxF "$f" .git/info/exclude || echo "$f" >> .git/info/exclude
  done
  echo "🔒 Added kit files to .git/info/exclude (won't be committed)."
fi

echo ""
echo "✅ Installed. Next steps:"
echo "   1) Edit .env.remote  → PROJECT_NAME, APP_HOST, VPS_SSH (+ MAIL_HOST/FLOWER_HOST)"
echo "   2) ./remote init     → create the docker context"
echo "   3) ./remote up       → build on the VPS + deploy"
