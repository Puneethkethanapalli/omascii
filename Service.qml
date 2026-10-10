import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "components"

// One instance per shell. Owns the backend calls and the file watches, and
// exposes the current state to every bar widget and panel (one per monitor)
// through bar.shell.serviceFor(id).
Item {
  id: root

  // Injected by omarchy-shell's service loader.
  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string binPath: decodeURIComponent(Qt.resolvedUrl("bin/omascii").toString().replace(/^file:\/\//, ""))

  // ---------------------------------------------------------------- state

  property var snapshot: ({})
  readonly property bool ready: snapshot.ok === true
  readonly property bool figletInstalled: ready && snapshot.engine && snapshot.engine.figlet === true
  readonly property bool screensaverOff: ready && snapshot.screensaverOff === true
  readonly property bool stayAwake: ready && snapshot.stayAwake === true
  readonly property int screensaverSeconds: ready && snapshot.idle ? Number(snapshot.idle.screensaver) : 0
  readonly property int lockSeconds: ready && snapshot.idle ? Number(snapshot.idle.lock) : 0
  readonly property var art: ready && snapshot.art ? snapshot.art : ({})
  readonly property var history: ready && Array.isArray(snapshot.history) ? snapshot.history : []
  readonly property bool menuInstalled: ready && snapshot.menu ? snapshot.menu.installed === true : false
  // Some effects switched off: omascii runs the screensaver itself.
  readonly property bool customEffects: ready && snapshot.effects ? snapshot.effects.mode === "custom" : false
  readonly property var effectsSummary: ready && snapshot.effects ? snapshot.effects : null
  property var effects: []
  property string lastError: ""
  property string lastMessage: ""

  // ------------------------------------------------------------ rendering

  property string renderedText: ""
  property var styles: []
  property var renderBudget: ({})
  // Every style by id and name, for picking one before any text is typed.
  property var catalog: []
  property string renderError: ""
  readonly property bool rendering: renderJob.busy || root._renderRequest !== null
  property var _renderRequest: null
  property string _renderingText: ""

  function command(args) {
    return ["bash", root.binPath].concat(args)
  }

  function parse(output) {
    try {
      return JSON.parse(output)
    } catch (e) {
      return null
    }
  }

  function refresh() {
    refreshDebounce.restart()
  }

  function _refreshNow() {
    if (stateJob.busy) {
      root._refreshQueued = true
      return
    }
    root._refreshQueued = false
    stateJob.run(command(["state"]))
  }
  property bool _refreshQueued: false

  // Size limits from the widget settings, or none: the backend then fits the
  // monitors the screensaver runs on.
  function limitArgs(maxCols, maxRows) {
    var args = []
    if (maxCols > 0) args.push("--max-cols", String(maxCols))
    if (maxRows > 0) args.push("--max-rows", String(maxRows))
    return args
  }

  // Latest request wins: typing fast never queues stale renders.
  function render(text, maxCols, maxRows) {
    var clean = String(text || "").trim()
    if (clean === "") {
      root._renderRequest = null
      root.renderedText = ""
      root.styles = []
      root.renderError = ""
      return
    }
    root._renderRequest = { text: clean, maxCols: maxCols, maxRows: maxRows }
    root._pumpRender()
  }

  function _pumpRender() {
    if (renderJob.busy || root._renderRequest === null) return
    var request = root._renderRequest
    root._renderRequest = null
    root._renderingText = request.text
    renderJob.run(command(["render", "--all", "--text", request.text]
      .concat(root.limitArgs(request.maxCols, request.maxRows))))
  }

  // -------------------------------------------------------------- actions

  // Mutations run one at a time, in order; each refreshes state afterwards.
  property var _queue: []
  property var _currentCallback: null

  function act(args, callback) {
    root._queue = root._queue.concat([{ args: args, callback: callback || null }])
    root._pumpActions()
  }

  function _pumpActions() {
    if (actionJob.busy || root._queue.length === 0) return
    var next = root._queue[0]
    root._queue = root._queue.slice(1)
    root._currentCallback = next.callback
    actionJob.run(command(next.args))
  }

  function apply(text, styleId, maxCols, maxRows, force, callback) {
    var args = ["apply", "--text", text, "--style", styleId].concat(root.limitArgs(maxCols, maxRows))
    if (force) args.push("--force")
    act(args, callback)
  }

  function restore(target, callback) { act(["restore", target], callback) }
  function removeHistory(sha, callback) { act(["history", "remove", sha], callback) }
  function setScreensaverDelay(seconds) { act(["idle", "set", "--screensaver", String(seconds)]) }
  function setLockDelay(seconds) { act(["idle", "set", "--lock", String(seconds)]) }
  function setScreensaverEnabled(on) { act(["screensaver", on ? "on" : "off"]) }
  function setStayAwake(on) { act(["awake", on ? "on" : "off"]) }
  function setMenuEntry(on) { act(["menu", on ? "install" : "uninstall"]) }

  function takeEffects(ok, result) {
    if (ok && result && Array.isArray(result.effects)) root.effects = result.effects
    else act(["effects"], root.takeEffects)
  }

  // Flip the switch at once; the backend's answer then replaces the list
  // (or restores it, e.g. when the last effect can't be switched off).
  function setEffect(id, on) {
    var next = []
    for (var i = 0; i < root.effects.length; i++) {
      var e = root.effects[i]
      next.push(e.id === id ? { id: e.id, description: e.description, enabled: on } : e)
    }
    root.effects = next
    act(["effects", "set", id, on ? "on" : "off"], root.takeEffects)
  }

  function allEffects() { act(["effects", "all"], root.takeEffects) }

  // Detached launches outlive the shell's own process tree.
  function launch(argv) {
    Util.execArgv(argv)
  }

  // ---------------------------------------------------------------- jobs

  CommandJob {
    id: stateJob
    timeoutMs: 8000
    onFinished: function(ok, output, error) {
      var parsed = root.parse(output)
      if (ok && parsed && parsed.ok === true) {
        root.snapshot = parsed
        // Effects changed elsewhere (another monitor, the command line):
        // reload the list when the counts disagree.
        var e = parsed.effects
        if (e && !actionJob.busy) {
          var on = 0
          for (var i = 0; i < root.effects.length; i++) if (root.effects[i].enabled) on++
          if (e.total !== root.effects.length || e.enabled !== on) act(["effects"], root.takeEffects)
        }
      } else root.lastError = (parsed && parsed.error) || error || "could not read state"
      if (root._refreshQueued) root._refreshNow()
    }
  }

  CommandJob {
    id: renderJob
    timeoutMs: 15000
    onFinished: function(ok, output, error) {
      var parsed = root.parse(output)
      if (ok && parsed && parsed.ok === true) {
        root.renderedText = parsed.text
        root.renderBudget = parsed.budget || ({})
        root.styles = parsed.styles || []
        root.renderError = ""
      } else {
        root.renderedText = root._renderingText
        root.styles = []
        root.renderError = (parsed && parsed.error) || error || "render failed"
      }
      root._pumpRender()
    }
  }

  CommandJob {
    id: actionJob
    timeoutMs: 20000
    onFinished: function(ok, output, error) {
      var parsed = root.parse(output)
      var success = ok && parsed !== null && parsed.ok === true
      var message = success ? "" : ((parsed && parsed.error) || error || "command failed")
      root.lastError = message
      var callback = root._currentCallback
      root._currentCallback = null
      if (callback) callback(success, parsed, message)
      root.refresh()
      root._pumpActions()
    }
  }

  Timer {
    id: refreshDebounce
    interval: 120
    repeat: false
    onTriggered: root._refreshNow()
  }

  // ------------------------------------------------------------- watches
  //
  // Directory watches see files appear, vanish, and get replaced by rename
  // (the toggles, the stay-awake indicator, atomic config writes); file
  // watches see in-place edits. A watch is re-armed after every event
  // because a rename drops it.

  FileView {
    id: togglesWatch
    path: root.home + "/.local/state/omarchy/toggles"
    preload: false
    watchChanges: true
    printErrors: false
    onFileChanged: {
      // The Omarchy menu's screensaver toggle lands here too; while omascii
      // runs the screensaver, sync reads it as the user's on/off choice.
      if (root.customEffects) act(["effects", "sync"])
      root.refresh()
      reload()
    }
  }

  FileView {
    id: indicatorsWatch
    path: root.home + "/.local/state/omarchy/indicators"
    preload: false
    watchChanges: true
    printErrors: false
    onFileChanged: { root.refresh(); reload() }
  }

  FileView {
    id: configDirWatch
    path: root.home + "/.config/omarchy"
    preload: false
    watchChanges: true
    printErrors: false
    onFileChanged: { root.refresh(); reload() }
  }

  FileView {
    id: brandingDirWatch
    path: root.home + "/.config/omarchy/branding"
    preload: false
    watchChanges: true
    printErrors: false
    onFileChanged: { root.refresh(); reload() }
  }

  FileView {
    id: shellJsonWatch
    path: root.home + "/.config/omarchy/shell.json"
    preload: false
    watchChanges: true
    printErrors: false
    onFileChanged: { root.refresh(); reload() }
  }

  FileView {
    id: artWatch
    path: root.home + "/.config/omarchy/branding/screensaver.txt"
    preload: false
    watchChanges: true
    printErrors: false
    onFileChanged: { root.refresh(); reload() }
  }

  // ------------------------------------------------------- own screensaver
  //
  // While effects are customised, Omarchy's screensaver is held off and this
  // starts omascii's at the same idle delay. Omarchy's idle service still
  // owns the lock timer and tracks the window (same class), so locking and
  // dismissal behave exactly as before.

  IdleMonitor {
    id: idleMonitor
    enabled: root.customEffects && !root.screensaverOff && !root.stayAwake && root.screensaverSeconds > 0
    timeout: root.screensaverSeconds
    respectInhibitors: true
    onIsIdleChanged: if (isIdle) Util.execArgv(["bash", root.binPath, "launch-screensaver"])
  }

  readonly property string pluginId: "io.github.puneethkethanapalli.omascii"

  // Disabled or removed (not just reloaded): give Omarchy its screensaver
  // back. Inline on purpose, since the plugin folder may already be gone.
  readonly property string releaseScript: [
    'state="${XDG_STATE_HOME:-$HOME/.local/state}/omascii"',
    '[[ -f $state/owns-screensaver-flag ]] || exit 0',
    'grep -qs "\\"$1\\"" "$HOME/.config/omarchy/shell.json" && exit 0',
    'flag="$HOME/.local/state/omarchy/toggles/screensaver-off"',
    'if [[ -f $state/screensaver-off ]]; then mkdir -p "${flag%/*}"; touch "$flag"; else rm -f "$flag"; fi',
    'rm -f "$state/owns-screensaver-flag" "$state/screensaver-off"'
  ].join("\n")

  Component.onDestruction: Quickshell.execDetached(["bash", "-c", root.releaseScript, "omascii-release", root.pluginId])

  Component.onCompleted: {
    // Add the Style › Screensaver menu row on first run only; removing it
    // from the panel is remembered by the backend.
    act(["menu", "ensure"])
    act(["fonts"], function(ok, result) { if (ok && result) root.catalog = result.styles || [] })
    // Take the screensaver back over after a restart or re-enable.
    act(["effects", "sync"], root.takeEffects)
    root._refreshNow()
  }
}
