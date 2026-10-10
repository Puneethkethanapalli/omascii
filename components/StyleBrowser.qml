import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// ◀ name · i/N · cols×rows ▶, with a badge when the art is over budget.
Item {
  id: root

  property var styles: []
  property int index: 0
  property bool busy: false
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property string emptyText: ""
  property string budgetText: ""

  readonly property var current: styles.length > 0 ? styles[Math.min(index, styles.length - 1)] : null
  readonly property color dim: Qt.darker(foreground, 1.4)

  // The centre label opens the style picker.
  property bool pickerOpen: false
  readonly property bool hot: labelHover.hovered || root.pickerOpen

  signal stepRequested(int delta)
  signal pickerRequested()

  implicitHeight: Math.max(prev.height, label.implicitHeight)

  PanelActionButton {
    id: prev
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    iconText: ""
    tooltipText: "Previous style (↑)"
    foreground: root.foreground
    enabled: root.styles.length > 1
    opacity: enabled ? 1 : 0.4
    onClicked: root.stepRequested(-1)
  }

  Rectangle {
    anchors.centerIn: labelRow
    width: labelRow.width + Style.space(16)
    height: Math.max(labelRow.height, prev.height)
    radius: Style.cornerRadius
    color: root.hot ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
  }

  Row {
    id: labelRow
    anchors.centerIn: parent
    spacing: Style.space(8)

    Text {
      id: label
      anchors.verticalCenter: parent.verticalCenter
      text: root.current ? Model.styleSummary(root.current, Math.min(root.index, root.styles.length - 1), root.styles.length)
        : (root.busy ? "rendering…" : root.emptyText)
      textFormat: Text.PlainText
      color: root.current ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: root.current !== null
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.current !== null && root.current.fits === false
      text: root.budgetText !== "" ? "TOO BIG FOR " + root.budgetText : "TOO BIG"
      textFormat: Text.PlainText
      color: Color.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Text {
      id: missingBadge
      anchors.verticalCenter: parent.verticalCenter
      visible: root.current !== null && root.current.fits !== false && !!root.current.missing
      text: "DROPS " + (root.current && root.current.missing ? root.current.missing : "")
      textFormat: Text.PlainText
      color: Color.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true

      HoverHandler { id: missingHover }
      PanelToolTip {
        visible: missingHover.hovered
        text: "This font has no glyph for " + Model.missingLabel(root.current) + "; it is left out of the art"
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.pickerOpen ? "󰅃" : "󰅀"
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  // Covers the label row. The DROPS badge keeps its tooltip because hover
  // handlers do not block each other.
  MouseArea {
    anchors.fill: labelRow
    anchors.margins: -Style.space(8)
    cursorShape: Qt.PointingHandCursor
    onClicked: root.pickerRequested()

    HoverHandler { id: labelHover }
    PanelToolTip {
      visible: labelHover.hovered && !root.pickerOpen && !missingHover.hovered
      text: "Pick a style (Alt+↓)"
    }
  }

  PanelActionButton {
    id: next
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    iconText: ""
    tooltipText: "Next style (↓)"
    foreground: root.foreground
    enabled: root.styles.length > 1
    opacity: enabled ? 1 : 0.4
    onClicked: root.stepRequested(1)
  }
}
