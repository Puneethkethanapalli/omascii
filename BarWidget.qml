import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar entry point: the icon plus an eagerly loaded panel (built once per
// monitor). State and watches live in Service.qml so every monitor agrees.
BarWidget {
  id: root
  moduleName: "io.github.puneethkethanapalli.omascii"

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(root.moduleName) : null
  readonly property bool screensaverOff: service ? service.screensaverOff : false
  readonly property bool stayAwake: service ? service.stayAwake : false

  // The bar finds a widget's panel through these three members.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  // The panel is loaded standalone, so hand it what it cannot reach itself.
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root
  }

  // Size from bar metrics, not from the button that fills this item.
  implicitWidth: vertical ? barSize : Style.bar.statusSlot
  implicitHeight: vertical ? Style.bar.statusSlot : barSize

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    text: "󱄄"
    dimmed: root.screensaverOff && !root.stayAwake
    active: root.stayAwake
    activeColor: Color.accent
    tooltipText: Model.tooltip(root.service ? root.service.snapshot : null)
    onPressed: function(b) {
      if (b === Qt.RightButton && root.service) root.service.launch(["bash", root.service.binPath, "preview"])
      else root.toggle()
    }
  }
}
