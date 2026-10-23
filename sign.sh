#!/usr/bin/env bash
# Signs the extension as an unlisted (self-distributed) add-on, which lets
# release Firefox install it permanently.
#
# Requires an AMO account and API credentials:
#   https://addons.mozilla.org/developers/addon/api/key/
#
# Provide them via the environment or ~/.config/yt-dlp-firefox/amo.env:
#   WEB_EXT_API_KEY=user:12345678:123
#   WEB_EXT_API_SECRET=0123456789abcdef...
#
# Signing is per-version, so bump "version" in manifest.json before re-running.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/yt-dlp-firefox/amo.env"

if [[ -f $ENV_FILE ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

if [[ -z ${WEB_EXT_API_KEY:-} || -z ${WEB_EXT_API_SECRET:-} ]]; then
  echo "error: WEB_EXT_API_KEY and WEB_EXT_API_SECRET must be set" >&2
  echo "       see https://addons.mozilla.org/developers/addon/api/key/" >&2
  echo "       or put them in $ENV_FILE" >&2
  exit 1
fi

mkdir -p "$SCRIPT_DIR/dist"

command -v npx >/dev/null 2>&1 || {
  echo "error: npx (Node.js) is required to run web-ext" >&2
  exit 1
}

npx --yes web-ext sign \
  --source-dir "$SCRIPT_DIR" \
  --artifacts-dir "$SCRIPT_DIR/dist" \
  --channel unlisted \
  --api-key "$WEB_EXT_API_KEY" \
  --api-secret "$WEB_EXT_API_SECRET" \
  --ignore-files install.sh build.sh sign.sh README.md LICENSE .gitignore \
  '.github/**' 'native-messaging/**' 'dist/**'

cat <<EOF

Signed package written to $SCRIPT_DIR/dist/
Install it permanently with:
  firefox "$(ls -t "$SCRIPT_DIR"/dist/*.xpi | head -n1)"
or about:addons -> gear icon -> "Install Add-on From File…"
EOF
