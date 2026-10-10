#!/usr/bin/env bash

# Install omascii from this checkout, for development. Everyone else:
#
#   omarchy plugin add https://github.com/puneethkethanapalli/omascii.git --enable --yes
#   omarchy pkg add figlet
#
# The checkout is copied, not symlinked: the shell's reload watcher does not
# follow symlinks and the validator rejects them. Re-run after edits.

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "$0")" && pwd)
ID=$(jq -r '.id' "$ROOT/manifest.json")
DEST="$HOME/.config/omarchy/plugins/$ID"
FORCE=false

case ${1:-} in
  --force) FORCE=true ;;
  "") ;;
  *) echo "Usage: ./install.sh [--force]" >&2; exit 1 ;;
esac

omarchy-plugin-validate "$ROOT"

if [[ -d $DEST/.git ]] && ! $FORCE; then
  echo "$DEST is a git install (omarchy plugin add). Update it with 'omarchy plugin update $ID'," >&2
  echo "or pass --force to overwrite it with this checkout." >&2
  exit 1
fi

mkdir -p "$DEST"
rsync -a --delete --exclude .git "$ROOT/" "$DEST/"
echo "Copied to $DEST"

if ! command -v figlet >/dev/null 2>&1; then
  echo "Installing figlet…"
  omarchy-pkg-add figlet
fi

omarchy-shell shell rescanPlugins >/dev/null
# The rescan is asynchronous; wait for the shell to list the plugin.
for _ in {1..50}; do
  omarchy-shell shell listPlugins 2>/dev/null | jq -e --arg id "$ID" 'any(.[]; .id == $id)' >/dev/null && break
  sleep 0.1
done
if ! jq -e --arg id "$ID" '[.bar.layout[]?[]? | (.id? // .)] | index($id)' \
  "$HOME/.config/omarchy/shell.json" >/dev/null 2>&1; then
  omarchy-plugin-enable "$ID" --section right
fi

echo "omascii is on the bar (right side)."
echo "To add it under Style › Screensaver in the Omarchy menu, turn on 'In Omarchy menu' in its panel."
