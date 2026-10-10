# omascii

Turn your text into ASCII art for the [Omarchy](https://omarchy.org) screensaver, straight from the top bar.

![omascii panel](preview.png)

Click the bar icon, type something, and step through 19 figlet styles with a live preview. Press **Apply** and the
Omarchy screensaver shows your art the next time it runs, with its usual random effects. The same panel also gathers
the screensaver and idle settings stock Omarchy offers, so they're all in one place.

## Features

- **Text → ASCII art.** 19 bundled styles:
  - Unicode block fonts, which suit the screensaver best: Delta Corps Priest, ANSI Shadow, Bloody, DOS Rebel, ANSI Regular, Electronic, Elite, Calvin S and Kompakt Block.
  - Classic figlet fonts: 3D ASCII, Larry 3D, Star Wars, Big Money, Graffiti, Big, Doom, Slant, Standard and Small.
  - Some fonts have no digits or punctuation. When your text uses a character a style can't draw, that style is marked **DROPS** and listed after the ones that draw everything.
  - The art is sized to your screens: long text wraps, and overlong words split across lines. See [Fitting the screen](#fitting-the-screen).
  - A style that can't fit is flagged **TOO BIG** and listed last. A second Apply uses it anyway.
- **Recent arts.** The last arts you used, with one-click restore. Art you set another way (from an image, or by editing the file) is saved before omascii replaces it, so nothing is lost.
- **Screensaver effects.** The **Effects** button lists all of ttfx's effects (37 today) with an on/off check and a ▶ preview for each. Switch off the ones you don't like: with one left on it loops, with several the screensaver picks one at random each cycle. See [Effects](#effects).
- **Stock controls.** Screensaver on/off, Stay Awake, screensaver and lock delays, Lock now, Preview, Set from image, Edit text, and Restore the Omarchy logo.
- **Bar icon** dims when the screensaver is off and lights up in your accent colour while staying awake. Right-click it to preview the screensaver.
- **Menu entry.** Style › Screensaver › **Generate from Text** opens the panel. Turn it off with the panel's *In Omarchy menu* switch.

omascii only changes what Omarchy already lets you change. It writes `~/.config/omarchy/branding/screensaver.txt` and the
`idle` block of `~/.config/omarchy/shell.json`, and uses Omarchy's own toggles. The screensaver itself (effects, font,
colours) is untouched.

## Install

Requires Omarchy 4 (the Quickshell shell).

```bash
omarchy plugin add https://github.com/puneethkethanapalli/omascii.git --enable --yes
omarchy pkg add figlet
```

If figlet is missing, the panel shows an **Install figlet** button instead of the generator.

## Use

| In the panel | Does |
|---|---|
| Type | Renders every style (after a short pause) |
| ↑ / ↓, ◀ / ▶ | Previous / next style |
| **Styles** button, Alt+↓, or click the style name | Open the style picker: every style with a preview of your text, its size and any warnings. Works before typing too, to choose a style up front |
| Enter | Apply |
| Ctrl+Enter | Apply and preview the screensaver |
| Alt+E | Open the Effects sheet |
| Esc | Close |

Open it from a keybinding by adding this to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + A", "omascii", "omarchy-shell shell toggle io.github.puneethkethanapalli.omascii")
```

### Command line

Everything the panel does goes through `bin/omascii` in the plugin folder, which also works on its own:

```bash
omascii=~/.config/omarchy/plugins/io.github.puneethkethanapalli.omascii/bin/omascii
$omascii render --text "hello" --style ansi-shadow --raw   # print the art
$omascii apply --text "hello" --style ansi-shadow          # set it as the screensaver
$omascii history                                           # recent arts (JSON)
$omascii restore default                                   # back to the Omarchy logo
$omascii idle set --screensaver 300 --lock 600             # delays in seconds
$omascii --help
```

Every command except `render --raw` and `--help` prints one line of JSON. On failure that's `{"ok":false,"error":…}`
with a non-zero exit.

## Effects

Omarchy's screensaver always plays a random effect from all of ttfx's effects. With every effect switched on (the
default), omascii leaves it exactly like that.

Once you switch some off, omascii runs the screensaver itself:

- It turns on Omarchy's "screensaver off" switch so the stock one stays quiet, and starts its own at the same idle
  delay, in the same full-screen window type (`org.omarchy.screensaver`).
- Omarchy's idle service still owns the lock timer and watches that window, so locking, dismissing with any key, Stay
  Awake and idle inhibitors behave as before.
- Effect changes apply from the next cycle; no restart needed.
- Turn every effect back on (**All on**) and Omarchy's own screensaver takes over again, with your on/off choice
  preserved. The same happens when the plugin is disabled or removed, even without `uninstall.sh`.

In the sheet: ↑/↓ move, Space toggles, **P** previews, **A** turns everything on, Esc closes. Alt+E opens it from the
text field.

From the command line:

```bash
$omascii effects                      # list with on/off
$omascii effects set blackhole off    # switch one off
$omascii effects only matrix          # loop a single effect
$omascii effects all                  # back to Omarchy's random effects
$omascii preview --effect rain        # play one effect once
```

## Fitting the screen

Omarchy draws the screensaver in an 18pt terminal on every monitor, and that size can't be changed. Instead, omascii
fits the art to it:

- **The size limit comes from your monitors.** omascii reads them with `hyprctl` and uses the smallest, since every
  screen shows the same art. For example, a 2880×1800 laptop panel at 2× scale fits 99×28 characters.
- **Long text wraps** at spaces, and a single word that's too wide is split across lines. When rows are tight, the
  blank row between lines is dropped.
- **Styles that fit are listed first.** If the style you picked stops fitting as you type, the panel shows the first
  one that does, and goes back to yours when the text gets shorter again.

A style is only marked **TOO BIG** when it can't fit at all, usually tall fonts like Delta Corps Priest with several
lines of text.

To use a fixed limit instead (say, for a smaller external monitor you sometimes plug in), set it on the bar entry in
`~/.config/omarchy/shell.json`:

```json
{ "id": "io.github.puneethkethanapalli.omascii", "maxCols": 80, "maxRows": 26 }
```

## Uninstall

```bash
omarchy plugin remove io.github.puneethkethanapalli.omascii
```

The Style › Screensaver row hides itself once omascii is gone. To delete it as well, switch off *In Omarchy menu* in the
panel before removing the plugin. From a checkout, `./uninstall.sh` does both and offers to restore the art you had
before omascii. `--purge` also deletes the saved history in `~/.local/state/omascii`.

## Development

```bash
./install.sh     # copy this checkout into ~/.config/omarchy/plugins, install figlet, enable on the bar
test/run         # backend tests, Model.js tests, manifest validation, qmllint, id consistency
```

`install.sh` copies rather than symlinks, because the shell's reload watcher doesn't follow symlinks. Re-run it after
edits; top-level QML reloads live. The shell caches files under `components/`, so after changing those, run
`omarchy restart shell`.

Layout:

- `bin/omascii`: bash + jq backend; all file writes are atomic (temp file + rename next to the target).
- `Service.qml`: one per shell. Holds state, watches Omarchy's toggle/indicator/config files, and queues backend calls.
- `BarWidget.qml`, `Panel.qml`, `components/`: the UI, built from Omarchy's `qs.Ui` kit.
- `Model.js`: pure helpers, tested with `node --test`.
- `fonts/`: bundled FIGlet fonts and `styles.json`, the style catalogue. See [fonts/FONTS.md](fonts/FONTS.md).

## License

[MIT](LICENSE). The bundled fonts keep their own terms; see [fonts/FONTS.md](fonts/FONTS.md).
