# Bundled fonts

FIGlet fonts shipped with omascii, renamed to lowercase-hyphenated file names. Copies were taken from the
[xero/figlet-fonts](https://github.com/xero/figlet-fonts) collection. Each file still carries its original header
comments. The only change is converting CRLF line endings to LF where a file had them.

| File | Original | Author / origin | Terms |
|---|---|---|---|
| `standard.flf` | Standard | Glenn Chappell & Ian Chai, 1993; Latin-2..5 by John Cowan | Ships with FIGlet. Header: "Permission is hereby given to modify this font, as long as the modifier's name is placed on a comment line." |
| `big.flf` | Big | Glenn Chappell, 1993; Greek by Bruce Jakeway; updated by Paul Burton | Same FIGlet font permission. |
| `slant.flf` | Slant | Glenn Chappell, 1993; updated by Paul Burton | Same FIGlet font permission. |
| `small.flf` | Small | Glenn Chappell, 1993; updated by Paul Burton | Same FIGlet font permission. |
| `doom.flf` | Doom | Frans P. de Vries, 1996, based on Big | Same FIGlet font permission. |
| `delta-corps-priest-1.flf` | Delta Corps Priest 1 | CoSMiC cHiLD (TheDraw font); FIGlet conversion via patorjk.com | No licence stated. Widely redistributed (figlet.js, xero/figlet-fonts). |
| `ansi-shadow.flf` | ANSI Shadow | Unknown author (TheDraw font); FIGlet conversion via patorjk.com | No licence stated. Widely redistributed. |
| `ansi-regular.flf` | ANSI Regular | Unknown author (TheDraw font); FIGlet conversion via patorjk.com | No licence stated. Widely redistributed. |
| `calvin-s.flf` | Calvin S | Unknown author (TheDraw font); FIGlet conversion via patorjk.com | No licence stated. Widely redistributed. |
| `bloody.flf` | Bloody | Unknown author; FIGlet conversion by patorjk, 2008 | No licence stated. Widely redistributed. |
| `dos-rebel.flf` | DOS Rebel | Valerie Mates, 1994, based on a font by Ron Bliss | No licence stated. Widely redistributed. |
| `electronic.flf` | Electronic | Derek Lemay (TheDraw font); FIGlet conversion via patorjk.com | No licence stated. Widely redistributed. |
| `elite.flf` | Elite | Unknown author (TheDraw font); FIGlet conversion via patorjk.com | No licence stated. Widely redistributed. |
| `kompakt-block.flf` | KompaktBlk | netspooky (n0.lol), 2022 | No licence stated. |
| `3d-ascii.flf` | 3D-ASCII | Unknown author (TheDraw font); FIGlet conversion via patorjk.com | No licence stated. Widely redistributed. |
| `larry-3d.flf` | Larry 3D | Larry Gelberg, tweaked by Glenn Chappell, 1994 | No licence stated. Widely redistributed. |
| `star-wars.flf` | Star Wars | Ryan Youck, 1994, based on Big | No licence stated. Widely redistributed. |
| `big-money.flf` | Big Money-ne | Nathan Bloomfield; modified by patorjk, 2007 | No licence stated. Widely redistributed. |
| `graffiti.flf` | Graffiti | Leigh Purdie and Tim Maggio | No licence stated. Widely redistributed. |

If you hold rights to one of these fonts and want it removed or credited differently, please open an issue.

## Adding a style

1. Drop the `.flf` file in this folder.
2. Add an entry to `styles.json`. Set `"unicode": true` for fonts drawn with block or box characters, so figlet kerns
   them instead of smushing, which would split multi-byte characters.
3. Run `test/font-coverage --write`. It fills in each style's `lacks` field: the printable characters the font has no
   glyph for. The panel uses it to warn before figlet silently drops them.
4. Run `test/run`. It checks, among other things, that every style renders "Hi" within 80×26 and that the `lacks`
   fields are current.
