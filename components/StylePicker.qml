import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Popup list of every style, opened from the style browser. Each row shows
// the text rendered in that style plus its size and warnings. Without text
// it lists the style names, so a style can be chosen before typing.
//
// Place it where the list should drop down from; it takes no space itself.
// Keyboard: Up/Down (or j/k) move, Enter picks, Esc closes.
Item {
  id: root

  property var styles: []
  property string currentId: ""
  property color foreground: Color.popups.text
  property color background: Color.popups.background
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property int visibleRows: 7

  readonly property bool opened: popup.opened
  readonly property int rowHeight: Style.space(42)
  readonly property var popupBorderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)

  signal picked(string id)
  signal closed()

  // A press outside the popup closes it before the click that opens it
  // lands, so a toggle right after closing would reopen it at once.
  property real _closedAt: 0

  function open() { if (root.styles.length > 0) popup.open() }
  function close() { popup.close() }
  function toggle() {
    if (popup.opened) popup.close()
    else if (Date.now() - root._closedAt > 300) root.open()
  }

  function indexOfCurrent() {
    for (var i = 0; i < root.styles.length; i++) if (root.styles[i].id === root.currentId) return i
    return 0
  }

  // Hover moves the selection only when the pointer really moved, not when
  // the list opens under a resting pointer.
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

  function badge(style) {
    if (!style || style.cols === undefined) return ""
    if (style.fits === false) return "TOO BIG"
    if (style.missing) return "DROPS " + style.missing
    return ""
  }

  height: 0

  Popup {
    id: popup
    x: 0
    y: Style.spacing.xxs
    width: root.width
    implicitHeight: Math.min(root.styles.length, root.visibleRows) * (root.rowHeight + Style.spacing.labelGap)
      + topPadding + bottomPadding
    padding: Style.spacing.hairline
    leftPadding: Border.left(root.popupBorderSpec) + Style.spacing.hairline
    rightPadding: Border.right(root.popupBorderSpec) + Style.spacing.hairline
    topPadding: Border.top(root.popupBorderSpec) + Style.spacing.hairline
    bottomPadding: Border.bottom(root.popupBorderSpec) + Style.spacing.hairline
    focus: true

    background: BorderSurface {
      color: root.background
      borderSpec: root.popupBorderSpec
      radius: Style.cornerRadius
    }

    onOpened: {
      root._pointerKnown = false
      list.currentIndex = root.indexOfCurrent()
      list.positionViewAtIndex(list.currentIndex, ListView.Contain)
      list.forceActiveFocus()
    }
    onClosed: {
      root._closedAt = Date.now()
      root.closed()
    }

    contentItem: ListView {
      id: list
      spacing: Style.spacing.labelGap
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: root.styles
      currentIndex: -1
      highlightMoveDuration: 0

      function pickCurrent() {
        if (currentIndex < 0 || currentIndex >= root.styles.length) return
        var id = root.styles[currentIndex].id
        popup.close()
        root.picked(id)
      }

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          popup.close()
          event.accepted = true
        } else if (event.key === Qt.Key_Down || event.text === "j") {
          list.currentIndex = Math.min(root.styles.length - 1, list.currentIndex + 1)
          event.accepted = true
        } else if (event.key === Qt.Key_Up || event.text === "k") {
          list.currentIndex = Math.max(0, list.currentIndex - 1)
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
          list.pickCurrent()
          event.accepted = true
        }
      }

      delegate: Rectangle {
        id: row
        required property var modelData
        required property int index
        readonly property bool hot: index === list.currentIndex
        readonly property bool chosen: modelData.id === root.currentId
        readonly property string warning: root.badge(row.modelData)

        width: list.width
        height: root.rowHeight
        radius: Style.cornerRadius
        color: hot ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"

        Rectangle {
          id: thumb
          visible: !!row.modelData.art
          anchors.left: parent.left
          anchors.leftMargin: Style.spacing.md
          anchors.verticalCenter: parent.verticalCenter
          width: visible ? Style.space(104) : 0
          height: parent.height - Style.spacing.md
          radius: Style.cornerRadius
          color: Util.alpha(root.foreground, 0.04)

          AsciiPreview {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            art: String(row.modelData.art || "")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }
        }

        Column {
          anchors.left: thumb.right
          anchors.leftMargin: Style.spacing.controlPaddingX
          anchors.right: check.left
          anchors.rightMargin: Style.spacing.md
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(1)

          Text {
            width: parent.width
            text: row.modelData.name
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: row.hot ? Style.hoverStateColor(root.foreground, root.accent) : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: row.chosen
          }

          Row {
            spacing: Style.spacing.md
            visible: row.modelData.cols !== undefined

            Text {
              text: row.modelData.cols + "×" + row.modelData.rows
              textFormat: Text.PlainText
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              visible: row.warning !== ""
              text: row.warning
              textFormat: Text.PlainText
              color: Color.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }

        Text {
          id: check
          anchors.right: parent.right
          anchors.rightMargin: Style.spacing.controlPaddingX
          anchors.verticalCenter: parent.verticalCenter
          text: row.chosen ? "󰄬" : ""
          textFormat: Text.PlainText
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onPositionChanged: function(mouse) {
            if (root.pointerMoved(row, mouse.x, mouse.y)) list.currentIndex = row.index
          }
          onClicked: {
            list.currentIndex = row.index
            list.pickCurrent()
          }
        }
      }
    }
  }
}
