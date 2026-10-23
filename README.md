# yt-dlp for Firefox

Firefox port of Omarchy's **Download Video** Chromium extension. Click the
toolbar icon (or press `Alt+Shift+D`) on a page and the video is downloaded with
`yt-dlp`, with Omarchy's OSD progress bar and a desktop notification when it
finishes.

## Attribution

The original extension is part of [Omarchy](https://github.com/basecamp/omarchy)
by [Basecamp](https://basecamp.com) / DHH, and ships at:

```
/usr/share/omarchy/default/chromium/extensions/yt-dlp
```

This is a Firefox-compatible port of that extension: the manifest and background
script are adapted (Firefox event page, `browser.*` promise API, `gecko` add-on
ID), while Omarchy's native messaging host — which does the actual downloading,
OSD updates and notifications — is reused unchanged.

Omarchy is MIT licensed; see [LICENSE](LICENSE) for both copyright notices.

## How it works

```
toolbar click / Alt+Shift+D
        ↓
background.js  (Firefox extension)
        ↓  native messaging: {"url": "https://…"}
com.omarchy.ytdlp  →  /usr/share/omarchy/bin/omarchy-chromium-ytdlp-host
        ↓
yt-dlp  →  ~/Videos  (Omarchy OSD + notification)
```

The native host is browser-agnostic: Firefox and Chromium both speak the same
stdio framing, so only the registration differs.

## Requirements

- Firefox 140+ (tested on 158)
- Omarchy, providing `omarchy-chromium-ytdlp-host`
- `yt-dlp`, `jq`; `ffmpeg` for notification thumbnails

## Setup

Clone the repository and register the native messaging host for Firefox (writes
only under `$HOME`):

```bash
git clone https://github.com/brunomnsilva/yt-dlp-firefox.git
cd yt-dlp-firefox
./install.sh
```

This creates `~/.mozilla/native-messaging-hosts/com.omarchy.ytdlp.json`
(pointing at Omarchy's host and allowing the add-on ID `yt-dlp@omarchy.local`).
It also registers the XDG path (`${XDG_CONFIG_HOME:-~/.config}/mozilla/…`) for
forward compatibility, plus the Flatpak Firefox paths if that profile exists.

Registering the host is a separate step from installing the extension, and it
is **per machine**: a signed `.xpi` that is copied or synced to another computer
still needs `./install.sh` run there.

Check the registration at any time:

```bash
./install.sh --check
```

It reports the host executable and every manifest found, and exits non-zero if
nothing is registered or a manifest points at a stale path.

### Temporary install (unsigned, no account needed)

```bash
./install.sh --zip        # optional: builds dist/yt-dlp-firefox-<version>.zip
```

1. Open `about:debugging#/runtime/this-firefox`
2. **Load Temporary Add-on…**
3. Select `manifest.json` (or the built zip)

The extension works immediately but **is removed every time Firefox
restarts** — this is a release-Firefox restriction for unsigned add-ons.

### Permanent install (signed)

Release Firefox only installs signed add-ons permanently. Sign it as an
unlisted/self-distributed add-on (free, no public listing, no review wait):

```bash
# One-time: get API credentials at
# https://addons.mozilla.org/developers/addon/api/key/
cat > ~/.config/yt-dlp-firefox/amo.env <<'EOF'
WEB_EXT_API_KEY=user:12345678:123
WEB_EXT_API_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF

./sign.sh
```

Then install the produced `dist/*.xpi` via
`about:addons → gear → Install Add-on From File…`.

Bump `"version"` in `manifest.json` before each re-sign. Alternative for
development: use Firefox Developer Edition / Nightly with
`xpinstall.signatures.required = false`.

## Usage

- Click the toolbar icon, or press `Alt+Shift+D`.
- The URL is only accepted when it starts with `http://` or `https://`;
  privileged pages (`about:`, addons.mozilla.org) are ignored.
- Downloads land in `~/Videos` (override with `OMARCHY_YTDLP_DIR` for the host).

## Files

| File | Purpose |
|---|---|
| `manifest.json` | MV3 manifest; Firefox event page + gecko ID |
| `background.js` | Sends the active tab URL to the native host |
| `icon-16.png`, `icon-48.png`, `icon-128.png` | Icons derived from the original Chromium extension |
| `native-messaging/com.omarchy.ytdlp.json` | Firefox host manifest template (`allowed_extensions`) |
| `install.sh` | Installs/uninstalls the host manifest, `--check` diagnostics, optional zip build |
| `build.sh` | Builds `dist/yt-dlp-firefox-<version>.zip` (no Omarchy required) |
| `sign.sh` | Builds and signs an unlisted XPI with `web-ext` |
| `.github/workflows/` | CI (lint, shellcheck, build) and tag-based releases |

## Development

The extension is plain HTML/JS — no bundler or build step is needed to run it.

```bash
./install.sh                  # register the native host once
./install.sh --check          # verify the host registration
./build.sh                    # produce dist/yt-dlp-firefox-<version>.zip
npx --yes web-ext lint        # what CI runs
npx --yes web-ext run         # launch a scratch Firefox with the add-on loaded
```

CI runs on every push and pull request:

- `web-ext lint` plus `node --check` and JSON validation
- `shellcheck` on all shell scripts
- a zip build, uploaded as a workflow artifact

Tagging a commit (`git tag v1.0.0 && git push --tags`) triggers the release
workflow, which builds the zip and attaches it to a GitHub Release. Release
builds are unsigned; sign locally with `./sign.sh` for a permanent install.

## Troubleshooting

`No such native application com.omarchy.ytdlp` (or a silent no-op when clicking
the toolbar icon) means the native messaging manifest is missing, points at a
nonexistent host, or the add-on ID does not match `allowed_extensions`.

```bash
./install.sh --check        # show the host and every manifest found
./install.sh                # (re)register the manifest paths
```

Then restart Firefox and try again.

Firefox 158 moved profiles to `~/.config/mozilla/firefox`, but native messaging
manifests are still read from the legacy `~/.mozilla/native-messaging-hosts`
path for compatibility ([Firefox bug 2005167](https://bugzilla.mozilla.org/show_bug.cgi?id=2005167)).
`install.sh` writes both locations, so the extension keeps working whichever
path Firefox uses.

## Uninstall

```bash
./install.sh --uninstall
```

Then remove the add-on from `about:addons` (or it disappears by itself after a
temporary-install restart). Omarchy's own Chromium host registration is never
touched.

## License

[MIT](LICENSE). The upstream Omarchy extension is MIT licensed as well.
