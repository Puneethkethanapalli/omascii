#!/usr/bin/env bash

# Backend tests for bin/omascii. Each test runs against a throwaway HOME and
# a fake OMARCHY_PATH, with mock omarchy-* commands first on PATH, so the
# real config is never touched.

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
OMASCII="$ROOT/bin/omascii"
FIXTURES="$ROOT/test/fixtures"

passed=0
failed=0
current=""

fail() {
  echo "  FAIL [$current] $*"
  failed=$((failed + 1))
}

ok() { passed=$((passed + 1)); }

assert_eq() {
  if [[ $1 == "$2" ]]; then ok; else fail "${3:-} expected [$2] got [$1]"; fi
}

assert_true() {
  if eval "$1"; then ok; else fail "${2:-$1}"; fi
}

setup() {
  current=$1
  SANDBOX=$(mktemp -d)
  export HOME="$SANDBOX/home"
  export OMARCHY_PATH="$SANDBOX/omarchy"
  export XDG_STATE_HOME="$HOME/.local/state"
  export XDG_CONFIG_HOME="$HOME/.config"
  mkdir -p "$HOME/.config/omarchy/branding" "$HOME/.config/omarchy/extensions" \
    "$OMARCHY_PATH/config/omarchy" "$SANDBOX/mocks"
  cp "$FIXTURES/logo.txt" "$OMARCHY_PATH/logo.txt"
  cp "$FIXTURES/logo.txt" "$HOME/.config/omarchy/branding/screensaver.txt"
  cp "$FIXTURES/default-shell.json" "$OMARCHY_PATH/config/omarchy/shell.json"
  cp "$FIXTURES/user-shell.json" "$HOME/.config/omarchy/shell.json"
  cp "$FIXTURES/menu.jsonc" "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"

  cat >"$SANDBOX/mocks/omarchy-shell" <<'EOF'
#!/bin/bash
echo "$*" >>"$HOME/omarchy-shell.calls"
EOF
  cat >"$SANDBOX/mocks/omarchy-toggle" <<'EOF'
#!/bin/bash
flag="$HOME/.local/state/omarchy/toggles/$1"
case ${2:-toggle} in
  on) mkdir -p "${flag%/*}"; touch "$flag" ;;
  off) rm -f "$flag" ;;
esac
EOF
  cat >"$SANDBOX/mocks/omarchy-toggle-idle" <<'EOF'
#!/bin/bash
file="$HOME/.local/state/omarchy/indicators/stay-awake"
case $1 in
  stay-awake) mkdir -p "${file%/*}"; touch "$file" ;;
  allow-idle) rm -f "$file" ;;
esac
EOF
  # Four effects, so effect tests don't depend on the installed ttfx.
  printf '%s\n' '#!/bin/bash' 'cat <<EOT' 'Usage: ttfx [OPTIONS] [COMMAND]' '' 'Commands:' \
    '  beams            Create beams' '  decrypt          Movie style decryption' \
    '  matrix           Matrix digital rain effect' '  rain             Rain characters' \
    '  help             Print this message' '' 'Options:' '  -R, --random-effect' 'EOT' \
    >"$SANDBOX/mocks/ttfx"
  # No monitors by default, so renders use the fixed 80x26 fallback.
  printf '%s\n' '#!/bin/bash' '[[ -f $HOME/monitors.json ]] || exit 1' 'cat "$HOME/monitors.json"' \
    >"$SANDBOX/mocks/hyprctl"
  chmod +x "$SANDBOX/mocks/"*
  export PATH="$SANDBOX/mocks:$ORIGINAL_PATH"
}

teardown() { rm -rf -- "$SANDBOX"; }

run() { "$OMASCII" "$@"; }

ORIGINAL_PATH=$PATH
ART="\$HOME/.config/omarchy/branding/screensaver.txt"
# Wraps onto enough lines that Delta Corps Priest can't fit 26 rows.
TALL_TEXT="good night everyone sleep well"

# ------------------------------------------------------------------ render

setup "render fits every style"
out=$(run render --all --text "Hi")
assert_eq "$(jq -r '.ok' <<<"$out")" true
assert_eq "$(jq '.styles | length' <<<"$out")" "$(jq length "$ROOT/fonts/styles.json")" "style count"
assert_eq "$(jq '[.styles[] | select(.fits != true)] | length' <<<"$out")" 0 "styles over budget"
assert_eq "$(jq '[.styles[] | select(.art == "")] | length' <<<"$out")" 0 "empty renders"
teardown

setup "render wraps long text within the width"
out=$(run render --text "good night from omarchy" --style ansi-shadow)
cols=$(jq '.cols' <<<"$out")
rows=$(jq '.rows' <<<"$out")
assert_true "((cols <= 80))" "cols $cols > 80"
assert_true "((rows > 6))" "expected wrapping onto several lines, got $rows rows"
art=$(jq -r '.art' <<<"$out")
widest=$(LC_ALL=C.UTF-8 awk '{ if (length($0) > w) w = length($0) } END { print w }' <<<"$art")
assert_eq "$widest" "$cols" "reported width"
assert_true "! grep -q '[[:space:]]$' <<<\"\$art\"" "trailing whitespace in art"
teardown

setup "render centres narrower lines"
art=$(run render --text "wide wordsss i" --style standard --max-cols 40 --raw)
first_char=$(tail -1 <<<"$art" | cut -c1)
assert_eq "$first_char" " " "last (narrower) block should be indented"
teardown

setup "render cleans text"
out=$(run render --text "  Café   🙂  " --style small)
assert_eq "$(jq -r '.text' <<<"$out")" "Cafe :-)"
teardown

setup "render rejects empty text"
out=$(run render --all --text "   ")
assert_eq "$?" 1 "exit code"
assert_eq "$(jq -r '.ok' <<<"$out")" false
teardown

setup "render flags oversize art"
out=$(run render --text "$TALL_TEXT" --style delta-corps-priest-1)
assert_eq "$(jq -r '.fits' <<<"$out")" false
teardown

setup "render splits a word too wide for one line"
out=$(run render --all --text "supercalifragilisticexpialidocious")
assert_eq "$(jq -r '.styles[] | select(.id == "ansi-shadow") | .fits' <<<"$out")" true "ANSI Shadow should fit once split"
assert_eq "$(jq '[.styles[] | select(.cols > 80)] | length' <<<"$out")" 0 "lines wider than the budget"
teardown

setup "render drops line gaps to fit the rows"
out=$(run render --text "good night" --style ansi-shadow --max-cols 50 --max-rows 12)
assert_eq "$(jq -c '[.rows, .fits]' <<<"$out")" "[12,true]"
assert_eq "$(jq -r '.art' <<<"$out" | grep -c '^$')" 0 "blank separator row kept"
out=$(run render --text "good night" --style ansi-shadow --max-cols 50)
assert_eq "$(jq -r '.art' <<<"$out" | grep -c '^$')" 1 "separator dropped when there was room"
teardown

setup "render lists fitting styles first"
out=$(run render --all --text "$TALL_TEXT")
assert_eq "$(jq -r '[.styles[].fits] | . == (sort | reverse)' <<<"$out")" true "fitting styles not first"
assert_eq "$(jq -r '.styles[] | select(.id == "delta-corps-priest-1") | .fits' <<<"$out")" false "tall text should not fit Delta Corps Priest"
teardown

setup "render reports characters a style can't draw"
out=$(run render --all --text "it's 7pm")
assert_eq "$(jq -r '.styles[] | select(.id == "bloody") | .missing' <<<"$out")" "'7"
assert_eq "$(jq -r '.styles[] | select(.id == "dos-rebel") | .missing' <<<"$out")" ""
assert_eq "$(jq -r '[.styles[] | select(.fits) | .missing == ""] | . == (sort | reverse)' <<<"$out")" true \
  "complete styles not listed before those that drop characters"
teardown

setup "render leaves out styles that draw nothing"
out=$(run render --all --text "2026")
assert_eq "$(jq '[.styles[] | select(.id == "delta-corps-priest-1" or .id == "bloody" or .id == "elite")] | length' <<<"$out")" 0
assert_eq "$(jq '[.styles[] | select(.art == "")] | length' <<<"$out")" 0
out=$(run apply --text "2026" --style delta-corps-priest-1)
assert_eq "$(jq -r '.ok' <<<"$out")" false
assert_true "cmp -s '$OMARCHY_PATH/logo.txt' \"$ART\"" "empty art applied"
teardown

setup "budget falls back without monitors"
assert_eq "$(run render --text "hi" --style small | jq -c '.budget')" '{"cols":80,"rows":26,"source":"default"}'
assert_eq "$(run render --text "hi" --style small --max-cols 40 --max-rows 10 | jq -c '.budget')" '{"cols":40,"rows":10,"source":"setting"}'
teardown

setup "budget fits the smallest monitor"
# The 2880x1800 @2 panel measured 99x28 in the real screensaver terminal.
echo '[{"width":2880,"height":1800,"scale":2,"transform":0}]' >"$HOME/monitors.json"
assert_eq "$(run state | jq -c '.budget')" '{"cols":99,"rows":28,"source":"screen"}'
echo '[{"width":2880,"height":1800,"scale":2,"transform":0},{"width":1920,"height":1080,"scale":1,"transform":1}]' >"$HOME/monitors.json"
assert_eq "$(run render --text "hi" --style small | jq -c '.budget')" '{"cols":72,"rows":28,"source":"screen"}' "rotated second monitor"
teardown

# ---------------------------------------------------------- apply/restore

setup "apply writes art and history"
logo_sha=$(sha256sum "$OMARCHY_PATH/logo.txt" | cut -d' ' -f1)
out=$(run apply --text "hello" --style ansi-shadow)
assert_eq "$(jq -r '.ok' <<<"$out")" true
art_file=$(eval echo "$ART")
assert_true "grep -q '██' '$art_file'" "art not written"
assert_true "cmp -s '$OMARCHY_PATH/logo.txt' '$XDG_STATE_HOME/omascii/original.txt'" "original not saved"
hist=$(run history)
assert_eq "$(jq '.history | length' <<<"$hist")" 2 "history entries"
assert_eq "$(jq -r '.history[0].current' <<<"$hist")" true "newest is current"
assert_eq "$(jq -r '.history[1].sha' <<<"$hist")" "$logo_sha" "previous art kept"
assert_eq "$(jq -r '.history[1].label' <<<"$hist")" "Omarchy logo"
assert_eq "$(find "$HOME" -name '.omascii.*' | wc -l)" 0 "temp files left behind"
teardown

setup "apply refuses oversize art unless forced"
out=$(run apply --text "$TALL_TEXT" --style delta-corps-priest-1)
assert_eq "$?" 1 "exit code"
assert_true "cmp -s '$OMARCHY_PATH/logo.txt' \"$ART\"" "art changed despite refusal"
out=$(run apply --text "$TALL_TEXT" --style delta-corps-priest-1 --force)
assert_eq "$(jq -r '.ok' <<<"$out")" true
teardown

setup "apply keeps a symlinked art file a symlink"
art_file=$(eval echo "$ART")
mv "$art_file" "$SANDBOX/real-art.txt"
ln -s "$SANDBOX/real-art.txt" "$art_file"
run apply --text "hi" --style small >/dev/null
assert_true "[[ -L '$art_file' ]]" "symlink replaced"
assert_true "grep -q '_' '$SANDBOX/real-art.txt'" "target not updated"
teardown

setup "restore default and by sha"
run apply --text "one" --style small >/dev/null
first_sha=$(run history | jq -r '.history[0].sha')
run apply --text "two" --style small >/dev/null
out=$(run restore default)
assert_eq "$(jq -r '.ok' <<<"$out")" true
assert_true "cmp -s '$OMARCHY_PATH/logo.txt' \"$ART\"" "default not restored"
out=$(run restore "$first_sha")
assert_eq "$(jq -r '.ok' <<<"$out")" true
assert_eq "$(sha256sum "$(eval echo "$ART")" | cut -d' ' -f1)" "$first_sha" "sha restore"
assert_eq "$(run history | jq '[.history[] | .sha] | unique | length')" "$(run history | jq '.history | length')" "history has duplicates"
out=$(run restore not-a-sha)
assert_eq "$(jq -r '.ok' <<<"$out")" false
teardown

setup "history is capped at four"
for i in $(seq 1 7); do run apply --text "n$i" --style small >/dev/null; done
assert_eq "$(run history | jq '.history | length')" 4
assert_eq "$(run state | jq '.history | length')" 4 "state shows more than the cap"
assert_eq "$(find "$XDG_STATE_HOME/omascii/history" -name '*.txt' | wc -l)" 4 "pruned files"
assert_eq "$(run history | jq -r '.history[0].label')" "n7 · Small" "newest first"
assert_true "[[ -f '$XDG_STATE_HOME/omascii/original.txt' ]]" "original pruned"
teardown

setup "history remove deletes a previous art"
run apply --text "one" --style small >/dev/null
run apply --text "two" --style small >/dev/null
old_sha=$(run history | jq -r '.history[] | select(.label == "one · Small") | .sha')
out=$(run history remove "$old_sha")
assert_eq "$(jq -r '.ok' <<<"$out")" true
assert_eq "$(jq '[.history[] | select(.sha == "'"$old_sha"'")] | length' <<<"$out")" 0 "entry still listed"
assert_true "[[ ! -e '$XDG_STATE_HOME/omascii/history/$old_sha.txt' ]]" "art file kept"
current_sha=$(run history | jq -r '.history[] | select(.current) | .sha')
assert_eq "$(run history remove "$current_sha" | jq -r '.ok')" false "removed the art on screen"
assert_eq "$(run history | jq '[.history[] | select(.current)] | length')" 1
assert_eq "$(run history remove "$(printf 'a%.0s' {1..64})" | jq -r '.ok')" false "unknown entry"
assert_eq "$(run history remove nope | jq -r '.ok')" false "malformed sha"
teardown

# -------------------------------------------------------------------- idle

setup "idle set preserves other keys and order"
before_keys=$(jq -c 'keys_unsorted' "$HOME/.config/omarchy/shell.json")
before_bar=$(jq -c '.bar' "$HOME/.config/omarchy/shell.json")
out=$(run idle set --screensaver 120)
assert_eq "$(jq -r '.ok' <<<"$out")" true
assert_eq "$(jq -c 'keys_unsorted' "$HOME/.config/omarchy/shell.json")" "$before_keys" "key order"
assert_eq "$(jq -c '.bar' "$HOME/.config/omarchy/shell.json")" "$before_bar" "bar changed"
assert_eq "$(jq '.idle.screensaver' "$HOME/.config/omarchy/shell.json")" 120
assert_eq "$(jq '.idle.lock' "$HOME/.config/omarchy/shell.json")" 600 "lock untouched"
assert_true "grep -q 'shell reloadConfig' '$HOME/omarchy-shell.calls'" "reloadConfig not called"
teardown

setup "idle set keeps lock at or after screensaver"
run idle set --screensaver 900 >/dev/null
assert_eq "$(jq '.idle.lock' "$HOME/.config/omarchy/shell.json")" 900 "lock raised"
run idle set --lock 120 >/dev/null
assert_eq "$(jq '.idle.screensaver' "$HOME/.config/omarchy/shell.json")" 120 "screensaver lowered"
run idle set --screensaver 5 >/dev/null
assert_eq "$(jq '.idle.screensaver' "$HOME/.config/omarchy/shell.json")" 60 "clamped to minimum"
teardown

setup "idle set refuses invalid shell.json"
echo '{ broken' >"$HOME/.config/omarchy/shell.json"
out=$(run idle set --screensaver 120)
assert_eq "$(jq -r '.ok' <<<"$out")" false
assert_eq "$(cat "$HOME/.config/omarchy/shell.json")" "{ broken" "file modified"
teardown

setup "idle set without shell.json starts from defaults"
rm "$HOME/.config/omarchy/shell.json"
assert_eq "$(run idle get | jq -r '.source')" defaults
run idle set --lock 900 >/dev/null
assert_eq "$(jq -r '.bar.marker' "$HOME/.config/omarchy/shell.json")" default-bar "defaults not copied"
assert_eq "$(jq '.idle.lock' "$HOME/.config/omarchy/shell.json")" 900
teardown

# -------------------------------------------------------------------- menu

setup "menu install is idempotent and uninstall is exact"
menu="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
original=$(cat "$menu")
run menu install >/dev/null
once=$(cat "$menu")
run menu install >/dev/null
assert_eq "$(cat "$menu")" "$once" "second install changed the file"
assert_eq "$(grep -c 'style.screensaver.omascii' "$menu")" 1
assert_true "sed -E '/^[[:space:]]*\/\//d' '$menu' | perl -0pe 's/,(\s*[}\]])/\$1/g' | jq -e . >/dev/null" "menu no longer parses"
run menu uninstall >/dev/null
assert_eq "$(cat "$menu")" "$original" "uninstall not byte-identical"
teardown

setup "menu ensure respects a removal"
run menu ensure >/dev/null
assert_eq "$(run menu status | jq -r '.installed')" true
run menu uninstall >/dev/null
run menu ensure >/dev/null
assert_eq "$(run menu status | jq -r '.installed')" false "ensure re-added a removed row"
teardown

setup "menu install creates a missing file"
rm "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
run menu install >/dev/null
assert_eq "$(run menu status | jq -r '.installed')" true
teardown

setup "menu install refuses a malformed file"
printf '{\n  "a": {"label": "x"\n}\n' >"$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
out=$(run menu install)
assert_eq "$(jq -r '.ok' <<<"$out")" false
teardown

# ----------------------------------------------------------------- effects

FLAG="\$HOME/.local/state/omarchy/toggles/screensaver-off"

setup "effects start all on, leaving the stock screensaver alone"
out=$(run effects)
assert_eq "$(jq -c '[.effects[].id]' <<<"$out")" '["beams","decrypt","matrix","rain"]'
assert_eq "$(jq -c '[.mode, .enabled, .total]' <<<"$out")" '["stock",4,4]'
assert_eq "$(run effects args | jq -c '.args')" '["--random-effect"]'
assert_true "[[ ! -e $(eval echo "$FLAG") ]]" "stock flag touched"
teardown

setup "switching an effect off takes over the screensaver"
out=$(run effects set rain off)
assert_eq "$(jq -c '[.mode, .enabled]' <<<"$out")" '["custom",3]'
assert_true "[[ -f $(eval echo "$FLAG") ]]" "Omarchy screensaver not suppressed"
assert_eq "$(run state | jq -r '.screensaverOff')" false "user choice should still be on"
assert_eq "$(run effects args | jq -c '.args')" '["--include-effects","beams","decrypt","matrix","--random-effect"]'
run effects set decrypt off >/dev/null
run effects set beams off >/dev/null
assert_eq "$(run effects args | jq -c '.args')" '["matrix"]' "a single effect should loop"
out=$(run effects set matrix off)
assert_eq "$(jq -r '.ok' <<<"$out")" false "the last effect could be switched off"
assert_eq "$(run effects args matrix | jq -c '.args')" '["matrix"]'
assert_eq "$(run effects set nosuch off | jq -r '.ok')" false
teardown

setup "turning every effect back on hands the screensaver back"
run effects set rain off >/dev/null
run effects all >/dev/null
assert_eq "$(run effects | jq -r '.mode')" stock
assert_true "[[ ! -e $(eval echo "$FLAG") ]]" "Omarchy screensaver still suppressed"
assert_true "[[ ! -e $XDG_STATE_HOME/omascii/owns-screensaver-flag ]]" "hold not released"
teardown

setup "the screensaver switch follows whoever runs the screensaver"
run screensaver off >/dev/null
run effects only matrix >/dev/null
assert_eq "$(run state | jq -r '.screensaverOff')" true "off choice lost on takeover"
run screensaver on >/dev/null
assert_eq "$(run state | jq -r '.screensaverOff')" false
assert_true "[[ -f $(eval echo "$FLAG") ]]" "flag released while omascii runs the screensaver"
run screensaver off >/dev/null
run effects all >/dev/null
assert_true "[[ -f $(eval echo "$FLAG") ]]" "off choice lost on hand-back"
assert_eq "$(run state | jq -r '.screensaverOff')" true
teardown

setup "the Omarchy menu toggle turns the screensaver back on"
run screensaver off >/dev/null
run effects only beams >/dev/null
rm -f "$(eval echo "$FLAG")"
run effects sync >/dev/null
assert_eq "$(run state | jq -r '.screensaverOff')" false
assert_true "[[ -f $(eval echo "$FLAG") ]]" "flag not held again after sync"
teardown

setup "release hands the flag back but keeps the effect choice"
run effects only beams >/dev/null
run effects release >/dev/null
assert_true "[[ ! -e $(eval echo "$FLAG") ]]" "flag kept after release"
assert_eq "$(run effects | jq -r '.enabled')" 1 "effect choice lost"
run effects sync >/dev/null
assert_true "[[ -f $(eval echo "$FLAG") ]]" "sync did not take over again"
teardown

# ---------------------------------------------------------------- toggles

setup "screensaver and stay-awake toggles"
assert_eq "$(run screensaver off | jq -r '.screensaverOff')" true
assert_eq "$(run state | jq -r '.screensaverOff')" true
assert_eq "$(run screensaver on | jq -r '.screensaverOff')" false
assert_eq "$(run awake on | jq -r '.stayAwake')" true
assert_eq "$(run state | jq -r '.stayAwake')" true
assert_eq "$(run awake off | jq -r '.stayAwake')" false
teardown

setup "state reports art and engine"
out=$(run state)
assert_eq "$(jq -r '.ok' <<<"$out")" true
assert_eq "$(jq -r '.art.isDefault' <<<"$out")" true
assert_eq "$(jq -r '.engine.figlet' <<<"$out")" true
assert_true "[[ -d '$HOME/.local/state/omarchy/toggles' && -d '$HOME/.local/state/omarchy/indicators' ]]" "watch dirs not created"
teardown

echo "backend: $passed passed, $failed failed"
((failed == 0))
