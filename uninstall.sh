#!/usr/bin/env bash

# Remove omascii: the menu row, the plugin, and (with --purge) its saved
# history. The screensaver art stays as it is unless you choose to restore
# what you had before omascii. figlet is left installed.

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "$0")" && pwd)
ID=$(jq -r '.id' "$ROOT/manifest.json")
DEST="$HOME/.config/omarchy/plugins/$ID"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omascii"
PURGE=false

case ${1:-} in
  --purge) PURGE=true ;;
  "") ;;
  *) echo "Usage: ./uninstall.sh [--purge]" >&2; exit 1 ;;
esac

OMASCII="$ROOT/bin/omascii"
[[ -x $DEST/bin/omascii ]] && OMASCII="$DEST/bin/omascii"

"$OMASCII" menu uninstall --forget >/dev/null || echo "Could not remove the menu row; see ~/.config/omarchy/extensions/omarchy-menu.jsonc" >&2
# Hand the screensaver back to Omarchy if omascii was running it.
"$OMASCII" effects release >/dev/null 2>&1 || true

if [[ -f $STATE_DIR/original.txt && -t 0 && -t 1 ]] && command -v gum >/dev/null 2>&1; then
  if gum confirm "Restore the screensaver art you had before omascii?"; then
    "$OMASCII" restore original >/dev/null && echo "Restored your original screensaver art."
  fi
fi

if [[ -e $DEST || -L $DEST ]]; then
  omarchy-plugin-remove "$ID" --yes
fi

if $PURGE; then
  rm -rf -- "$STATE_DIR" "${XDG_CONFIG_HOME:-$HOME/.config}/omascii"
  echo "Removed $STATE_DIR and the saved effect choice"
fi
