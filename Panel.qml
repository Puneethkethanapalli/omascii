import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "components"

// The omascii panel: type text, browse the rendered styles, apply one to the
// screensaver; below that, recent arts and the stock idle controls.
Panel {
  id: root

  moduleName: "io.github.puneethkethanapalli.omascii"

  // Handed over by BarWidget.injectPanel().
  property var anchorItem: null
  property var hostWidget: null

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(root.moduleName) : null
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  // Optional size limits from the bar entry; 0 lets the backend fit the
  // monitors the screensaver runs on.
  readonly property int maxCols: Math.max(0, Number(setting("maxCols", 0)) || 0)
  readonly property int maxRows: Math.max(0, Number(setting("maxRows", 0)) || 0)
  readonly property var budget: service && service.renderBudget && service.renderBudget.cols > 0
    ? service.renderBudget : (service && service.snapshot.budget ? service.snapshot.budget : ({}))

  readonly property bool ready: service ? service.ready : false
  readonly property bool figletInstalled: service ? service.figletInstalled : false
  readonly property bool stayAwake: service ? service.stayAwake : false
  readonly property bool screensaverOff: service ? service.screensaverOff : false
  readonly property var art: service ? service.art : ({})
  readonly property var effectsCount: Model.countEffects(service ? service.effects : [])
  readonly property var history: service ? service.history.slice(0, 5) : []

  // ------------------------------------------------------------ generator

  readonly property bool hasInput: input.text.trim() !== ""
  readonly property var styles: service && hasInput ? service.styles : []
  property int styleIndex: 0
  property string styleId: ""
  readonly property var currentStyle: styles.length > 0 ? styles[Math.min(styleIndex, styles.length - 1)] : null
  property bool applying: false
  // An over-budget style needs a second Apply press; this holds what was armed.
  property string forceArmed: ""

  readonly property string fallbackNote: Model.fallbackNote(styles, styleId, styleIndex)
  // The picker lists the rendered styles, or just their names before any
  // text is typed, so a style can be chosen up front.
  readonly property var catalog: service ? service.catalog : []
  readonly property var pickerStyles: hasInput && styles.length > 0 ? styles : catalog
  readonly property string chosenName: {
    var i = Model.indexOfStyle(catalog, styleId)
    return i >= 0 ? catalog[i].name : ""
  }

  onStylesChanged: styleIndex = Model.pickIndex(styles, styleId, styleIndex)

  function pickStyle(id) {
    styleId = id
    var index = Model.indexOfStyle(styles, id)
    if (index >= 0) styleIndex = index
    forceArmed = ""
    refocusTimer.restart()
  }

  function focusInput() {
    if (figletInstalled) input.forceActiveFocus()
  }

  // Keys that reach the panel outside the text field, e.g. when a closing
  // popup leaves focus behind. Typing goes back into the field, and only
  // Enter applies, so a stray Space can never change the screensaver.
  function catcherKey(event) {
    if (input.activeFocus || picker.opened || effectsPicker.opened) return
    var plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
    if (event.key === Qt.Key_Escape) {
      close()
    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
      stepStyle(event.key === Qt.Key_Down ? 1 : -1)
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      applyCurrent((event.modifiers & Qt.ControlModifier) !== 0)
    } else if (event.key === Qt.Key_Backspace && figletInstalled) {
      focusInput()
      if (input.cursorPosition > 0) input.remove(input.cursorPosition - 1, input.cursorPosition)
    } else if (plain && figletInstalled && event.text.length === 1 && event.text >= " " && event.text !== "\x7f") {
      focusInput()
      input.insert(input.cursorPosition, event.text)
    } else {
      return
    }
    event.accepted = true
  }

  function stepStyle(delta) {
    if (styles.length === 0) return
    styleIndex = Model.step(styleIndex, delta, styles.length)
    styleId = styles[styleIndex].id
    forceArmed = ""
  }

  function applyCurrent(previewAfter) {
    if (!service || !currentStyle || applying || service.rendering) return
    var style = currentStyle
    var text = service.renderedText
    var key = style.id + "|" + text
    var force = !style.fits && forceArmed === key
    if (!style.fits && !force) {
      forceArmed = key
      say(style.name + " is " + style.cols + "×" + style.rows + ", bigger than the "
        + Model.budgetLabel(budget) + " the screensaver shows. Press Apply again to use it anyway.", true)
      return
    }
    applying = true
    service.apply(text, style.id, maxCols, maxRows, force, function(ok, result, error) {
      root.applying = false
      root.forceArmed = ""
      if (!ok) {
        root.say(error, true)
        return
      }
      root.say("Screensaver set to “" + text + "” in " + style.name + ".", false)
      if (previewAfter) root.previewScreensaver("")
    })
  }

  // ---------------------------------------------------------- idle delays

  readonly property int screensaverIndex: Model.nearestIndex(Model.SCREENSAVER_STOPS, (service ? service.screensaverSeconds : 0) / 60)
  readonly property int lockIndex: Model.nearestIndex(Model.LOCK_STOPS, (service ? service.lockSeconds : 0) / 60)
  // Hold a released slider position until the saved value catches up;
  // PanelSlider otherwise snaps back to the stale value.
  property int pendingScreensaverIndex: -1
  property int pendingLockIndex: -1
  readonly property int shownScreensaverIndex: pendingScreensaverIndex >= 0 ? pendingScreensaverIndex : screensaverIndex
  readonly property int shownLockIndex: pendingLockIndex >= 0 ? pendingLockIndex : lockIndex

  onScreensaverIndexChanged: if (pendingScreensaverIndex === screensaverIndex) pendingScreensaverIndex = -1
  onLockIndexChanged: if (pendingLockIndex === lockIndex) pendingLockIndex = -1

  function commitScreensaver(value) {
    var index = Math.round(value)
    if (!service || index === shownScreensaverIndex) return
    pendingScreensaverIndex = index
    pendingTimeout.restart()
    service.setScreensaverDelay(Model.SCREENSAVER_STOPS[index] * 60)
  }

  function commitLock(value) {
    var index = Math.round(value)
    if (!service || index === shownLockIndex) return
    pendingLockIndex = index
    pendingTimeout.restart()
    service.setLockDelay(Model.LOCK_STOPS[index] * 60)
  }

  // -------------------------------------------------------------- helpers

  property string notice: ""
  property bool noticeError: false

  function say(text, isError) {
    notice = String(text || "")
    noticeError = isError === true
    noticeTimer.restart()
  }

  // The panel sits on the overlay layer holding keyboard focus; get it out
  // of the way before anything else takes the screen.
  property var pendingLaunch: null
  function launchAfterClose(argv) {
    pendingLaunch = argv
    close()
    launchTimer.restart()
  }

  // Show the screensaver now; with an effect, play just that one once.
  function previewScreensaver(effect) {
    if (!service) return
    var argv = ["bash", service.binPath, "preview"]
    if (effect) argv.push("--effect", effect)
    launchAfterClose(argv)
  }

  function restore(target, label) {
    if (!service) return
    service.restore(target, function(ok, result, error) {
      root.say(ok ? "Restored " + label + "." : error, !ok)
    })
  }

  onOpenedChanged: if (!opened) {
    // Popups live in the panel window; close them with it.
    picker.close()
    effectsPicker.close()
  } else {
    notice = ""
    forceArmed = ""
    if (service) service.refresh()
    Qt.callLater(function() { if (root.figletInstalled) input.forceActiveFocus() })
  }

  Timer {
    id: renderDebounce
    interval: 250
    repeat: false
    onTriggered: if (root.service) root.service.render(input.text, root.maxCols, root.maxRows)
  }

  // Runs after a popup's own close handling, which can move focus away.
  Timer {
    id: refocusTimer
    interval: 60
    repeat: false
    onTriggered: root.focusInput()
  }

  Timer {
    id: launchTimer
    interval: 200
    repeat: false
    onTriggered: {
      if (root.service && root.pendingLaunch) root.service.launch(root.pendingLaunch)
      root.pendingLaunch = null
    }
  }

  Timer {
    id: pendingTimeout
    interval: 4000
    repeat: false
    onTriggered: {
      root.pendingScreensaverIndex = -1
      root.pendingLockIndex = -1
    }
  }

  Timer {
    id: noticeTimer
    interval: 6000
    repeat: false
    onTriggered: root.notice = ""
  }

  // While figlet is missing, poll so the panel unlocks right after install.
  Timer {
    interval: 3000
    repeat: true
    running: root.opened && root.ready && !root.figletInstalled
    onTriggered: if (root.service) root.service.refresh()
  }

  // ------------------------------------------------------------------ UI

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: root.figletInstalled ? input : keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(820))

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) { root.catcherKey(event) }

      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: scroller.width
          spacing: Style.space(10)

          // ---------- Hero: status line and stay-awake switch ----------
          PanelHero {
            width: parent.width
            title: "omascii"
            meta: Model.heroStatus(root.service ? root.service.snapshot : null)
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󱄄"
                textFormat: Text.PlainText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            trailingControl: Component {
              Row {
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "STAY AWAKE"
                  textFormat: Text.PlainText
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                ToggleSwitch {
                  id: stayAwakeSwitch
                  anchors.verticalCenter: parent.verticalCenter
                  enabled: root.ready
                  checked: root.stayAwake
                  foreground: root.foreground
                  onToggled: if (root.service) root.service.setStayAwake(!root.stayAwake)

                  PanelToolTip {
                    visible: stayAwakeSwitch.containsMouse
                    text: "Pause idle: no screensaver and no lock"
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---------- Generator ----------
          PanelSectionHeader {
            text: "SCREENSAVER TEXT"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.ready && !root.figletInstalled

            Text {
              width: parent.width
              text: "omascii draws its art with figlet, which isn't installed yet."
              textFormat: Text.PlainText
              wrapMode: Text.WordWrap
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Button {
              text: "Install figlet"
              iconText: ""
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.launchAfterClose(["omarchy-launch-floating-terminal-with-presentation", "omarchy-pkg-add figlet"])
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: root.figletInstalled || !root.ready

            TextField {
              id: input
              width: parent.width - stylesButton.width - parent.spacing
              enabled: root.figletInstalled
              maximumLength: 48
              placeholderText: "Type your text, e.g. good night"
              foreground: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body

              onTextChanged: {
                root.forceArmed = ""
                renderDebounce.restart()
              }

              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  root.close()
                  event.accepted = true
                } else if (event.key === Qt.Key_Down && (event.modifiers & Qt.AltModifier)) {
                  picker.open()
                  event.accepted = true
                } else if (event.key === Qt.Key_E && (event.modifiers & Qt.AltModifier)) {
                  effectsPicker.open()
                  event.accepted = true
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp) {
                  root.stepStyle(-1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown) {
                  root.stepStyle(1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  root.applyCurrent((event.modifiers & Qt.ControlModifier) !== 0)
                  event.accepted = true
                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                  // Nothing else in the panel takes keyboard focus; stay here.
                  event.accepted = true
                }
              }
            }


            Button {
              id: stylesButton
              height: input.height
              text: "Styles"
              iconText: "󰏘"
              bordered: true
              selected: picker.opened
              enabled: root.figletInstalled
              opacity: enabled ? 1 : 0.5
              foreground: root.foreground
              fontFamily: root.fontFamily
              tooltipText: "Pick a style (Alt+↓)"
              onClicked: picker.toggle()
            }
          }
          StyleBrowser {
            width: parent.width
            visible: root.figletInstalled
            styles: root.styles
            index: root.styleIndex
            busy: root.service ? root.service.rendering : false
            foreground: root.foreground
            fontFamily: root.fontFamily
            emptyText: root.hasInput ? ""
              : (root.chosenName !== "" ? "Current screensaver · type to try " + root.chosenName : "Current screensaver")
            budgetText: Model.budgetLabel(root.budget)
            pickerOpen: picker.opened
            onStepRequested: function(delta) { root.stepStyle(delta) }
            onPickerRequested: picker.toggle()

            StylePicker {
              id: picker
              anchors.top: parent.bottom
              width: parent.width
              styles: root.pickerStyles
              currentId: root.currentStyle ? root.currentStyle.id : root.styleId
              foreground: root.foreground
              fontFamily: root.fontFamily
              onPicked: function(id) { root.pickStyle(id) }
              onClosed: refocusTimer.restart()
            }
          }

          Text {
            width: parent.width
            visible: root.figletInstalled && root.fallbackNote !== ""
            text: root.fallbackNote
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Rectangle {
            width: parent.width
            height: Style.space(180)
            radius: Style.cornerRadius
            color: Util.alpha(root.foreground, 0.04)
            border.width: 1
            border.color: Util.alpha(root.foreground, 0.1)

            AsciiPreview {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              art: root.currentStyle ? root.currentStyle.art
                : (root.hasInput ? "" : String(root.art.text || ""))
              placeholder: root.service && root.service.renderError !== "" ? root.service.renderError
                : (root.hasInput ? "rendering…" : "No screensaver art yet")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
          }

          Row {
            spacing: Style.space(8)

            Button {
              visible: root.figletInstalled
              text: root.applying ? "Applying…" : (root.currentStyle && !root.currentStyle.fits ? "Apply anyway" : "Apply")
              iconText: ""
              bordered: true
              enabled: root.currentStyle !== null && !root.applying
              opacity: enabled ? 1 : 0.5
              foreground: root.foreground
              fontFamily: root.fontFamily
              tooltipText: "Enter · Ctrl+Enter applies and previews"
              onClicked: root.applyCurrent(false)
            }

            Button {
              text: "Preview screensaver"
              iconText: "󱄄"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.previewScreensaver("")
            }

            Button {
              id: effectsButton
              text: root.effectsCount.total > 0 && root.effectsCount.enabled < root.effectsCount.total
                ? "Effects · " + root.effectsCount.enabled + "/" + root.effectsCount.total : "Effects"
              iconText: "󰁨"
              bordered: true
              selected: effectsPicker.opened
              enabled: root.ready && root.effectsCount.total > 0
              opacity: enabled ? 1 : 0.5
              foreground: root.foreground
              fontFamily: root.fontFamily
              tooltipText: Model.effectsSummary(root.effectsCount) + " · choose which effects play (Alt+E)"
              onClicked: effectsPicker.toggle()
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---------- Recent arts and stock branding actions ----------
          PanelSectionHeader {
            text: "ART"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Repeater {
            model: root.history

            delegate: Item {
              required property var modelData
              width: column.width
              height: Style.space(40)

              Rectangle {
                id: thumb
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(120)
                height: parent.height
                radius: Style.cornerRadius
                color: Util.alpha(root.foreground, 0.04)

                AsciiPreview {
                  anchors.fill: parent
                  anchors.margins: Style.space(3)
                  art: String(modelData.art || "")
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }
              }

              Text {
                anchors.left: thumb.right
                anchors.leftMargin: Style.space(10)
                anchors.right: restoreButton.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                text: Model.shortLabel(modelData.label, 40)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: modelData.current ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: modelData.current === true
              }

              Button {
                id: restoreButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.current ? "Current" : "Restore"
                enabled: !modelData.current
                bordered: !modelData.current
                foreground: modelData.current ? root.dim : root.foreground
                fontFamily: root.fontFamily
                onClicked: root.restore(modelData.sha, "“" + modelData.label + "”")
              }
            }
          }

          Flow {
            width: parent.width
            spacing: Style.space(8)

            Button {
              text: "From image"
              iconText: ""
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              tooltipText: "Convert a PNG or SVG with omarchy-branding-screensaver"
              onClicked: root.launchAfterClose(["omarchy-branding-screensaver", "image"])
            }

            Button {
              text: "Edit text"
              iconText: ""
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              tooltipText: "Open screensaver.txt in your editor"
              onClicked: root.launchAfterClose(["omarchy-branding-screensaver", "text"])
            }

            Button {
              text: "Omarchy logo"
              iconText: "󰑓"
              bordered: true
              enabled: root.art.isDefault !== true
              opacity: enabled ? 1 : 0.5
              foreground: root.foreground
              fontFamily: root.fontFamily
              tooltipText: "Restore the default screensaver art"
              onClicked: root.restore("default", "the Omarchy logo")
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---------- Screensaver: on/off and its delay ----------
          Column {
            width: parent.width
            spacing: Style.space(6)
            opacity: root.stayAwake ? 0.4 : 1.0

            Item {
              width: parent.width
              implicitHeight: Math.max(screensaverHeader.implicitHeight, screensaverSwitch.implicitHeight)

              PanelSectionHeader {
                id: screensaverHeader
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "SCREENSAVER"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              ToggleSwitch {
                id: screensaverSwitch
                anchors.left: screensaverHeader.right
                anchors.leftMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                enabled: root.ready
                checked: !root.screensaverOff
                foreground: root.foreground
                onToggled: if (root.service) root.service.setScreensaverEnabled(root.screensaverOff)

                PanelToolTip {
                  visible: screensaverSwitch.containsMouse
                  text: "Show the screensaver after the delay below"
                }
              }

              Text {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                text: "after " + Model.minutesLabel(Model.SCREENSAVER_STOPS[
                  screensaverSlider.dragging ? Math.round(screensaverSlider.liveValue) : root.shownScreensaverIndex])
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            PanelSlider {
              id: screensaverSlider
              width: parent.width
              bar: root.bar
              enabled: root.ready
              opacity: root.screensaverOff ? 0.4 : 1.0
              minimum: 0
              maximum: Model.SCREENSAVER_STOPS.length - 1
              step: 1
              integer: true
              tickCount: Model.SCREENSAVER_STOPS.length
              value: root.shownScreensaverIndex
              onReleased: function(v) { root.commitScreensaver(v) }
            }

          }

          // ---------- Lock delay ----------
          Column {
            width: parent.width
            spacing: Style.space(6)
            opacity: root.stayAwake ? 0.4 : 1.0

            Item {
              width: parent.width
              implicitHeight: lockHeader.implicitHeight

              PanelSectionHeader {
                id: lockHeader
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "LOCK"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Text {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                text: "after " + Model.minutesLabel(Model.LOCK_STOPS[
                  lockSlider.dragging ? Math.round(lockSlider.liveValue) : root.shownLockIndex])
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            PanelSlider {
              id: lockSlider
              width: parent.width
              bar: root.bar
              enabled: root.ready
              minimum: 0
              maximum: Model.LOCK_STOPS.length - 1
              step: 1
              integer: true
              tickCount: Model.LOCK_STOPS.length
              value: root.shownLockIndex
              onReleased: function(v) { root.commitLock(v) }
            }
          }

          Item {
            width: parent.width
            implicitHeight: Math.max(lockNow.implicitHeight, menuSwitch.implicitHeight)

            Button {
              id: lockNow
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Lock now"
              iconText: ""
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.launchAfterClose(["omarchy-system-lock"])
            }

            Text {
              anchors.right: menuSwitch.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: "IN OMARCHY MENU"
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            ToggleSwitch {
              id: menuSwitch
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              enabled: root.ready
              checked: root.service ? root.service.menuInstalled : false
              foreground: root.foreground
              onToggled: if (root.service) root.service.setMenuEntry(!root.service.menuInstalled)

              PanelToolTip {
                visible: menuSwitch.containsMouse
                text: "Show “Generate from Text” under Style › Screensaver"
              }
            }
          }

          Text {
            width: parent.width
            visible: text !== ""
            text: root.notice !== "" ? root.notice : (root.service ? root.service.lastError : "")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: root.notice !== "" && !root.noticeError ? root.dim : Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }

      EffectsPicker {
        id: effectsPicker
        anchors.fill: parent
        effects: root.service ? root.service.effects : []
        summary: Model.effectsSummary(root.effectsCount)
        error: root.service ? root.service.lastError : ""
        foreground: root.foreground
        fontFamily: root.fontFamily
        onToggled: function(id, on) { if (root.service) root.service.setEffect(id, on) }
        onAllRequested: if (root.service) root.service.allEffects()
        onPreviewRequested: function(id) { root.previewScreensaver(id) }
        onClosed: refocusTimer.restart()
      }
    }
  }
}
