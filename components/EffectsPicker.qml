import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Sheet over the panel listing every ttfx effect with an on/off check and a
// ▶ preview. One effect on loops it; several are picked from at random.
// Fill the area the sheet should cover; it takes no input until opened.
// Keyboard: Up/Down move, Space or Enter toggles, P previews, A turns all
// on, Esc closes.
Item {
  id: root

  property var effects: []
  property string summary: ""
  property string error: ""
  property color foreground: Color.popups.text
  property color background: Color.popups.background
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  readonly property bool opened: popup.opened
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property int rowHeight: Style.space(34)
  readonly property var popupBorderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)

  signal toggled(string id, bool on)
  signal allRequested()
  signal previewRequested(string id)
  signal closed()

  // See StylePicker: ignore a toggle that lands right after a close.
  property real _closedAt: 0

  function open() { if (rows.count > 0) popup.open() }
  function close() { popup.close() }
  function toggle() {
    if (popup.opened) popup.close()
    else if (Date.now() - root._closedAt > 300) root.open()
  }

  function flip(index) {
    if (index < 0 || index >= rows.count) return
    var row = rows.get(index)
    root.toggled(row.effectId, !row.active)
  }

  // Rows are updated in place: replacing the model would rebuild every row,
  // scroll back to the top, and let the row under a resting mouse pointer
  // grab the selection.
  ListModel { id: rows }

  function syncRows() {
    var list = root.effects || []
    var same = rows.count === list.length
    for (var i = 0; same && i < list.length; i++) {
      if (rows.get(i).effectId !== list[i].id) same = false
    }
    if (!same) {
      rows.clear()
      for (var j = 0; j < list.length; j++) {
        rows.append({ effectId: list[j].id, details: list[j].description || "", active: list[j].enabled === true })
      }
      return
    }
    for (var k = 0; k < list.length; k++) {
      if (rows.get(k).active !== (list[k].enabled === true)) rows.setProperty(k, "active", list[k].enabled === true)
    }
  }

  onEffectsChanged: syncRows()
  Component.onCompleted: syncRows()

  // Hover moves the selection only when the pointer really moved, not when
  // a row appears under a resting pointer.
  // The first hover after opening only records where the pointer rests.
  property point _lastPointer: Qt.point(-1, -1)
  property bool _pointerKnown: false

  function pointerMoved(item, x, y) {
    var global = item.mapToGlobal(x, y)
    var known = root._pointerKnown
    var moved = global.x !== root._lastPointer.x || global.y !== root._lastPointer.y
    root._lastPointer = global
    root._pointerKnown = true
    return known && moved
  }

  Popup {
    id: popup
    x: 0
    y: 0
    width: root.width
    height: root.height
    padding: Style.spacing.lg
    focus: true

    background: BorderSurface {
      color: root.background
      borderSpec: root.popupBorderSpec
      radius: Style.cornerRadius
    }

    onOpened: {
      root._pointerKnown = false
      list.currentIndex = Math.max(0, list.currentIndex)
      list.forceActiveFocus()
    }
    onClosed: {
      root._closedAt = Date.now()
      root.closed()
    }

    contentItem: Item {
      Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.max(title.implicitHeight, allButton.implicitHeight, closeButton.size)

        Column {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          PanelSectionHeader {
            id: title
            text: "SCREENSAVER EFFECTS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            text: root.summary
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.md

          Button {
            id: allButton
            text: "All on"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            tooltipText: "Turn every effect back on (A)"
            onClicked: root.allRequested()
          }

          PanelActionButton {
            id: closeButton
            anchors.verticalCenter: parent.verticalCenter
            iconText: "✕"
            tooltipText: "Close (Esc)"
            foreground: root.foreground
            onClicked: popup.close()
          }
        }
      }

      PanelSeparator {
        id: rule
        anchors.top: header.bottom
        anchors.topMargin: Style.spacing.md
        foreground: root.foreground
      }

      ListView {
        id: list
        anchors.top: rule.bottom
        anchors.topMargin: Style.spacing.md
        anchors.bottom: footer.top
        anchors.bottomMargin: Style.spacing.md
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: rows
        spacing: Style.spacing.labelGap
        highlightMoveDuration: 0
        currentIndex: 0

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            popup.close()
          } else if (event.key === Qt.Key_Down || event.text === "j") {
            list.currentIndex = Math.min(rows.count - 1, list.currentIndex + 1)
          } else if (event.key === Qt.Key_Up || event.text === "k") {
            list.currentIndex = Math.max(0, list.currentIndex - 1)
          } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.flip(list.currentIndex)
          } else if (event.text === "p" || event.text === "P") {
            if (list.currentIndex >= 0 && list.currentIndex < rows.count) root.previewRequested(rows.get(list.currentIndex).effectId)
          } else if (event.text === "a" || event.text === "A") {
            root.allRequested()
          } else {
            return
          }
          event.accepted = true
        }

        delegate: Rectangle {
          id: row
          required property string effectId
          required property string details
          required property bool active
          required property int index
          readonly property bool hot: index === list.currentIndex

          width: list.width
          height: root.rowHeight
          radius: Style.cornerRadius
          color: hot ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: function(mouse) {
              if (root.pointerMoved(row, mouse.x, mouse.y)) list.currentIndex = row.index
            }
            onClicked: {
              list.currentIndex = row.index
              root.flip(row.index)
            }
          }

          Text {
            id: check
            anchors.left: parent.left
            anchors.leftMargin: Style.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            text: row.active ? "󰄲" : "󰄱"
            textFormat: Text.PlainText
            color: row.active ? root.accent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }

          Text {
            id: name
            anchors.left: check.right
            anchors.leftMargin: Style.spacing.lg
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(120)
            text: row.effectId
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: row.active ? root.foreground : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: row.active
          }

          Text {
            anchors.left: name.right
            anchors.leftMargin: Style.spacing.md
            anchors.right: play.left
            anchors.rightMargin: Style.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            text: row.details
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          PanelActionButton {
            id: play
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.xs
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰐊"
            tooltipText: "Preview " + row.effectId + " (P)"
            foreground: root.foreground
            onClicked: root.previewRequested(row.effectId)
          }
        }
      }

      Text {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: root.error !== "" ? root.error
          : "One effect on loops it; several play in random order. Space toggles · P previews · Esc closes"
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: root.error !== "" ? Color.urgent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
