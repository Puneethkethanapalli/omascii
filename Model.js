.pragma library

// Pure helpers shared by the panel and the bar widget. No QML imports, so
// test/model.test.js can load this file in node.

// Delay stops in minutes. Both map onto the backend's 60..7200 s range.
var SCREENSAVER_STOPS = [1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120]
var LOCK_STOPS = [1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120]

function nearestIndex(stops, minutes) {
  var best = 0
  for (var i = 1; i < stops.length; i++) {
    if (Math.abs(stops[i] - minutes) < Math.abs(stops[best] - minutes)) best = i
  }
  return best
}

function minutesLabel(minutes) {
  if (minutes >= 60 && minutes % 60 === 0) return (minutes / 60) + "h"
  if (minutes > 60) return Math.floor(minutes / 60) + "h " + (minutes % 60) + "m"
  return minutes + "m"
}

function secondsLabel(seconds) {
  if (!(seconds > 0)) return "–"
  if (seconds < 60) return seconds + "s"
  return minutesLabel(Math.round(seconds / 60))
}

// Wrap-around step through a list of length `count`.
function step(index, delta, count) {
  if (count <= 0) return 0
  return ((index + delta) % count + count) % count
}

function indexOfStyle(styles, styleId) {
  for (var i = 0; i < styles.length; i++) {
    if (styles[i].id === styleId) return i
  }
  return -1
}

// A style draws this text well when it fits the screen and has a glyph for
// every character (figlet silently drops the rest).
function usable(style) {
  return !!style && style.fits !== false && !style.missing
}

// Characters a style would drop, quoted for display: “'” “7”.
function missingLabel(style) {
  if (!style || !style.missing) return ""
  var parts = []
  for (var i = 0; i < style.missing.length; i++) parts.push("“" + style.missing.charAt(i) + "”")
  return parts.join(" ")
}

// Which style to show after a re-render. The chosen style stays while it
// draws the text well; otherwise show the first that does (the backend
// lists those first). The choice itself is kept, so it comes back when the
// text changes again.
function pickIndex(styles, preferredId, fallbackIndex) {
  if (styles.length === 0) return 0
  var preferred = indexOfStyle(styles, preferredId)
  if (preferred >= 0 && usable(styles[preferred])) return preferred
  if (usable(styles[0])) return 0
  if (preferred >= 0) return preferred
  return Math.max(0, Math.min(fallbackIndex, styles.length - 1))
}

// Why pickIndex stepped in, e.g. "Bloody can't draw “7”, showing DOS Rebel".
function fallbackNote(styles, preferredId, shownIndex) {
  var preferred = indexOfStyle(styles, preferredId)
  if (preferred < 0 || preferred === shownIndex || !styles[shownIndex]) return ""
  var style = styles[preferred]
  var reason = style.fits === false ? " is too big for this text" : " can't draw " + missingLabel(style)
  return style.name + reason + ", showing " + styles[shownIndex].name
}

// { enabled, total, only } from the effects list.
function countEffects(effects) {
  var list = effects || []
  var enabled = 0
  var only = ""
  for (var i = 0; i < list.length; i++) {
    if (list[i].enabled) {
      enabled++
      only = list[i].id
    }
  }
  return { enabled: enabled, total: list.length, only: enabled === 1 ? only : "" }
}

// "All 37 effects · random", "6 of 37 effects · random", "matrix · loops".
function effectsSummary(effects) {
  if (!effects || !(effects.total > 0)) return ""
  if (effects.enabled >= effects.total) return "All " + effects.total + " effects · random"
  if (effects.enabled === 1 && effects.only) return effects.only + " · loops"
  return effects.enabled + " of " + effects.total + " effects · random"
}

function budgetLabel(budget) {
  if (!budget || !(budget.cols > 0)) return ""
  return budget.cols + "×" + budget.rows
}

function heroStatus(state) {
  if (!state || state.ok !== true) return "loading…"
  if (state.stayAwake) return "staying awake · idle paused"
  var idle = state.idle || {}
  var lock = "lock " + secondsLabel(idle.lock)
  if (state.screensaverOff) return "screensaver off · " + lock
  return "screensaver " + secondsLabel(idle.screensaver) + " · " + lock
}

function tooltip(state) {
  return "omascii — " + heroStatus(state)
}

function styleSummary(style, index, count) {
  if (!style) return ""
  return style.name + " · " + (index + 1) + "/" + count + " · " + style.cols + "×" + style.rows
}

// Shorten a history label for a one-line row.
function shortLabel(text, max) {
  var s = String(text || "")
  return s.length > max ? s.slice(0, Math.max(0, max - 1)) + "…" : s
}
