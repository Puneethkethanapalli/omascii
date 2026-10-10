// Tests for Model.js. Run: node --test test/model.test.js
// Model.js is QML `.pragma library` JavaScript, so it is loaded by stripping
// the pragma and evaluating it in a fresh context.
"use strict"

const test = require("node:test")
const assert = require("node:assert")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
const Model = {}
vm.runInNewContext(source.replace(/^\.pragma library\s*$/m, ""), Model)

test("stays within the ES5 subset QML accepts", () => {
  const code = source.replace(/\/\/[^\n]*/g, "")
  for (const [name, pattern] of [["arrow function", /=>/], ["template literal", /`/],
    ["let", /\blet\b/], ["const", /\bconst\b/], ["class", /\bclass\b/]]) {
    assert.ok(!pattern.test(code), "Model.js uses " + name)
  }
})

test("nearestIndex snaps to the closest stop", () => {
  assert.strictEqual(Model.nearestIndex(Model.SCREENSAVER_STOPS, 5), 3)
  assert.strictEqual(Model.nearestIndex(Model.SCREENSAVER_STOPS, 2.5), 1)
  assert.strictEqual(Model.nearestIndex(Model.SCREENSAVER_STOPS, 0), 0)
  assert.strictEqual(Model.nearestIndex(Model.LOCK_STOPS, 999), Model.LOCK_STOPS.length - 1)
})

test("stops stay inside the backend's 60..7200 s range", () => {
  for (const minutes of Model.SCREENSAVER_STOPS.concat(Model.LOCK_STOPS)) {
    assert.ok(minutes * 60 >= 60 && minutes * 60 <= 7200, minutes + "m out of range")
  }
})

test("labels", () => {
  assert.strictEqual(Model.minutesLabel(5), "5m")
  assert.strictEqual(Model.minutesLabel(60), "1h")
  assert.strictEqual(Model.minutesLabel(90), "1h 30m")
  assert.strictEqual(Model.secondsLabel(150), "3m")
  assert.strictEqual(Model.secondsLabel(0), "–")
})

test("step wraps both ways", () => {
  assert.strictEqual(Model.step(0, -1, 9), 8)
  assert.strictEqual(Model.step(8, 1, 9), 0)
  assert.strictEqual(Model.step(3, 1, 0), 0)
})

test("pickIndex keeps the chosen style while it draws the text well", () => {
  const styles = [{ id: "a", fits: true, missing: "" }, { id: "b", fits: true, missing: "" },
    { id: "m", fits: true, missing: "7" }, { id: "c", fits: false, missing: "" }]
  assert.strictEqual(Model.pickIndex(styles, "b", 0), 1)
  assert.strictEqual(Model.pickIndex(styles, "c", 3), 0, "outgrown style falls back to the first usable one")
  assert.strictEqual(Model.pickIndex(styles, "m", 2), 0, "style dropping characters falls back too")
  assert.strictEqual(Model.pickIndex(styles, "gone", 7), 0)
  assert.strictEqual(Model.pickIndex(styles, "", 0), 0)
  assert.strictEqual(Model.pickIndex([], "a", 3), 0)
  const none = [{ id: "a", fits: false }, { id: "b", fits: false }]
  assert.strictEqual(Model.pickIndex(none, "b", 0), 1, "nothing usable: keep the choice")
})

test("usable and missingLabel", () => {
  assert.strictEqual(Model.usable({ fits: true, missing: "" }), true)
  assert.strictEqual(Model.usable({ fits: true, missing: "?" }), false)
  assert.strictEqual(Model.usable({ fits: false, missing: "" }), false)
  assert.strictEqual(Model.usable(null), false)
  assert.strictEqual(Model.missingLabel({ missing: "'7" }), "“'” “7”")
  assert.strictEqual(Model.missingLabel({ missing: "" }), "")
})

test("fallbackNote explains a switched style", () => {
  const styles = [{ id: "a", name: "Slant", fits: true, missing: "" }, { id: "c", name: "Delta", fits: false, missing: "" },
    { id: "m", name: "Bloody", fits: true, missing: "7" }]
  assert.strictEqual(Model.fallbackNote(styles, "c", 0), "Delta is too big for this text, showing Slant")
  assert.strictEqual(Model.fallbackNote(styles, "m", 0), "Bloody can't draw “7”, showing Slant")
  assert.strictEqual(Model.fallbackNote(styles, "a", 0), "")
  assert.strictEqual(Model.fallbackNote(styles, "", 0), "")
})

test("effect counts and summary", () => {
  const list = [{ id: "beams", enabled: true }, { id: "matrix", enabled: false }, { id: "rain", enabled: true }]
  assert.deepStrictEqual(JSON.parse(JSON.stringify(Model.countEffects(list))), { enabled: 2, total: 3, only: "" })
  assert.strictEqual(Model.countEffects([{ id: "matrix", enabled: true }, { id: "rain", enabled: false }]).only, "matrix")
  assert.strictEqual(Model.effectsSummary({ enabled: 37, total: 37 }), "All 37 effects · random")
  assert.strictEqual(Model.effectsSummary({ enabled: 6, total: 37 }), "6 of 37 effects · random")
  assert.strictEqual(Model.effectsSummary({ enabled: 1, total: 37, only: "matrix" }), "matrix · loops")
  assert.strictEqual(Model.effectsSummary({ enabled: 0, total: 0 }), "")
})

test("budgetLabel", () => {
  assert.strictEqual(Model.budgetLabel({ cols: 99, rows: 28 }), "99×28")
  assert.strictEqual(Model.budgetLabel({}), "")
  assert.strictEqual(Model.budgetLabel(null), "")
})

test("heroStatus describes the armed behaviour", () => {
  assert.strictEqual(Model.heroStatus(null), "loading…")
  const base = { ok: true, idle: { screensaver: 300, lock: 600 } }
  assert.strictEqual(Model.heroStatus(base), "screensaver 5m · lock 10m")
  assert.strictEqual(Model.heroStatus(Object.assign({}, base, { screensaverOff: true })), "screensaver off · lock 10m")
  assert.strictEqual(Model.heroStatus(Object.assign({}, base, { stayAwake: true })), "staying awake · idle paused")
})

test("styleSummary and shortLabel", () => {
  assert.strictEqual(Model.styleSummary({ name: "Big", cols: 40, rows: 6 }, 1, 9), "Big · 2/9 · 40×6")
  assert.strictEqual(Model.styleSummary(null, 0, 0), "")
  assert.strictEqual(Model.shortLabel("abcdef", 4), "abc…")
  assert.strictEqual(Model.shortLabel("abc", 4), "abc")
})
