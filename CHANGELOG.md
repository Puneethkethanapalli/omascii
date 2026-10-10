# Changelog

## 0.1.0 (2026-10-10)

First release.

- Bar widget and panel: type text, browse 19 figlet styles with a live preview, and apply one to the Omarchy
  screensaver.
- Art is fitted to the monitors the screensaver runs on (read from `hyprctl`). Long words split across lines, and
  the blank rows between lines are dropped when rows are tight. Styles that fit are listed first, and an outgrown style
  falls back to one that fits.
- Styles warn when the text uses characters their font has no glyph for (figlet would drop them), and are listed
  after the styles that draw everything.
- Style picker (the Styles button next to the text field, or Alt+↓): every style with a preview of the text, its size and warnings.
- Effects: switch individual ttfx effects on or off, with a preview for each. One effect loops; several play in
  random order. omascii runs the screensaver only while some effects are off, and hands it back to Omarchy otherwise
  (also when the plugin is disabled or removed).
- Recent arts: the last 4, each with restore and remove. Art set outside omascii is saved before it gets replaced.
- Stock screensaver/idle controls: on/off, Stay Awake, screensaver and lock delays, Lock now, Preview, Set from image,
  Edit text, Restore the Omarchy logo.
- "Generate from Text" row under Style › Screensaver in the Omarchy menu.
- `bin/omascii` backend usable from the command line.
