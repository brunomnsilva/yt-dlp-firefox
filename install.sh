#!/usr/bin/env bash
# Registers the yt-dlp native messaging host for Firefox.
#
# This only touches $HOME: it writes the Firefox native-messaging manifest and
# leaves Omarchy's native host (shared with the Chromium extension) untouched.

set -euo pipefail

HOST_NAME="com.omarchy.ytdlp"
EXT_ID="yt-dlp@omarchy.local"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
TEMPLATE="$SCRIPT_DIR/native-messaging/$HOST_NAME.json"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--zip] [--check] [--uninstall]

  (no args)    install the native messaging host manifest for Firefox
  --zip        also build dist/$HOST_NAME-<version>.zip for about:debugging
  --check      report whether the host and manifest are correctly registered
  --uninstall  remove the Firefox native messaging host manifest
EOF
}

host_path() {
  local candidate
  for candidate in \
    "$OMARCHY_PATH/bin/omarchy-chromium-ytdlp-host" \
    "/usr/bin/omarchy-chromium-ytdlp-host"; do
    if [[ -x $candidate ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

host_dirs() {
  printf '%s\n' "$HOME/.mozilla/native-messaging-hosts"
  # Firefox keeps native manifests on the legacy path for now, but bug 2005167
  # proposes moving them under the XDG config dir. Register both so this keeps
  # working when that lands.
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/native-messaging-hosts"
  # Flatpak Firefox keeps its own home inside the sandbox.
  if [[ -d $HOME/.var/app/org.mozilla.firefox ]]; then
    printf '%s\n' "$HOME/.var/app/org.mozilla.firefox/.mozilla/native-messaging-hosts"
    printf '%s\n' "$HOME/.var/app/org.mozilla.firefox/.config/mozilla/native-messaging-hosts"
  fi
}

render_manifest() {
  sed -e "s|__HOST_PATH__|$1|g" -e "s|__EXT_ID__|$EXT_ID|g" "$TEMPLATE"
}

check_deps() {
  local missing=() tool
  for tool in yt-dlp jq; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  command -v ffmpeg >/dev/null 2>&1 || echo "warning: ffmpeg not found; notifications won't have a thumbnail" >&2
  if ((${#missing[@]} > 0)); then
    echo "warning: missing ${missing[*]}; the native host needs them to download" >&2
  fi
}

build_zip() {
  "$SCRIPT_DIR/build.sh"
}

install_host() {
  local path manifest dir
  path=$(host_path) || {
    echo "error: native host omarchy-chromium-ytdlp-host not found (looked under $OMARCHY_PATH/bin and /usr/bin)" >&2
    echo "       is Omarchy installed?" >&2
    exit 1
  }
  check_deps
  manifest=$(render_manifest "$path")

  while IFS= read -r dir; do
    mkdir -p "$dir"
    printf '%s\n' "$manifest" >"$dir/$HOST_NAME.json"
    chmod 644 "$dir/$HOST_NAME.json"
    printf 'Installed %s\n' "$dir/$HOST_NAME.json"
  done < <(host_dirs)

  cat <<EOF

Next steps (temporary install — Firefox drops it on restart):
  1. Open about:debugging#/runtime/this-firefox
  2. Click "Load Temporary Add-on…"
  3. Select $SCRIPT_DIR/manifest.json
  4. Press Alt+Shift+D on a video page, or click the toolbar icon

For a permanent install, run ./sign.sh and then install the signed .xpi
(see README.md). No Firefox restart is needed after this script.
EOF
}

check_host() {
  local path manifest dir file status=0 found=false

  printf 'Native messaging host: %s\n' "$HOST_NAME"

  if path=$(host_path); then
    printf '  executable: %s\n' "$path"
  else
    printf '  executable: NOT FOUND (looked under %s/bin and /usr/bin)\n' "$OMARCHY_PATH"
    status=1
  fi

  manifest=""
  if [[ -n $path ]]; then
    manifest=$(render_manifest "$path")
  fi

  while IFS= read -r dir; do
    file="$dir/$HOST_NAME.json"
    [[ -f $file ]] || continue
    found=true
    if [[ -n $manifest ]] && diff -q <(printf '%s\n' "$manifest") "$file" >/dev/null; then
      printf '  manifest:   %s (ok)\n' "$file"
    else
      printf '  manifest:   %s (stale, re-run %s)\n' "$file" "$(basename "$0")"
      status=1
    fi
  done < <(host_dirs)

  if ! $found; then
    printf '  manifest:   not installed\n'
    printf '\nRun ./install.sh first, then restart Firefox before trying again.\n'
    status=1
  fi

  check_deps
  return "$status"
}

uninstall_host() {
  local dir
  while IFS= read -r dir; do
    if [[ -f $dir/$HOST_NAME.json ]]; then
      rm -f "$dir/$HOST_NAME.json"
      rmdir --ignore-fail-on-non-empty "$dir" 2>/dev/null || true
      printf 'Removed %s\n' "$dir/$HOST_NAME.json"
    fi
  done < <(host_dirs)
}

zip_requested=false
for arg in "$@"; do
  case $arg in
  --zip) zip_requested=true ;;
  --check)
    if check_host; then exit 0; else exit 1; fi
    ;;
  --uninstall)
    uninstall_host
    exit 0
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "error: unknown option: $arg" >&2
    usage >&2
    exit 2
    ;;
  esac
done

install_host
if $zip_requested; then
  build_zip
fi
