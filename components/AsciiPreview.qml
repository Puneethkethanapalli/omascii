import QtQuick
import QtQuick.Window
import qs.Commons

// Multi-line ASCII art shrunk to fit its box (never enlarged). The pixel
// size is chosen so each character cell is a whole number of device pixels
// and rows sit on whole pixels too; otherwise block glyphs land on fractional
// positions and their antialiased edges show as seams.
Item {
  id: root

  property string art: ""
  property string placeholder: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property int baseSize: Style.font.body
  property int minimumSize: 3

  readonly property bool showingArt: root.art !== ""
  readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
  readonly property real cellRatio: Math.max(0.1, metrics.advanceWidth("█") / metrics.font.pixelSize)
  readonly property real lineRatio: Math.max(0.1, metrics.height / metrics.font.pixelSize)
  readonly property var grid: root.measure(root.art)
  readonly property int fontSize: root.pickSize(root.grid.cols, root.grid.rows)

  function measure(text) {
    var lines = String(text || "").split("\n")
    var cols = 0
    for (var i = 0; i < lines.length; i++) cols = Math.max(cols, lines[i].length)
    return { cols: cols, rows: lines.length }
  }

  function pickSize(cols, rows) {
    if (cols <= 0 || rows <= 0 || root.width <= 0 || root.height <= 0) return root.baseSize
    var largest = Math.floor(Math.min(root.baseSize,
      root.width / (cols * root.cellRatio),
      root.height / (rows * root.lineRatio)))
    largest = Math.max(root.minimumSize, largest)
    // Prefer the largest nearby size with a whole-pixel cell width.
    for (var size = largest; size >= Math.max(root.minimumSize, largest - 8); size--) {
      var cell = size * root.cellRatio * root.dpr
      if (Math.abs(cell - Math.round(cell)) < 0.02) return size
    }
    return largest
  }

  clip: true

  FontMetrics {
    id: metrics
    font.family: root.fontFamily
    font.pixelSize: 100
  }

  Text {
    anchors.centerIn: parent
    visible: root.showingArt
    text: root.art
    textFormat: Text.PlainText
    wrapMode: Text.NoWrap
    renderType: Text.NativeRendering
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    lineHeightMode: Text.FixedHeight
    // Round down to whole device pixels: neighbouring rows overlap a hair
    // instead of leaving a gap.
    lineHeight: Math.max(1, Math.floor(root.fontSize * root.lineRatio * root.dpr) / root.dpr)
    // Thumbnails can be too small even at the minimum size; shrink the rest
    // of the way as a bitmap there (1 everywhere else, so no blur).
    scale: implicitWidth > 0 && implicitHeight > 0
      ? Math.min(1, root.width / implicitWidth, root.height / implicitHeight) : 1
  }

  Text {
    anchors.fill: parent
    visible: !root.showingArt && root.placeholder !== ""
    text: root.placeholder
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    color: Qt.darker(root.foreground, 1.6)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
