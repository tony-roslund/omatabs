import QtQuick
import qs.Commons
import qs.Ui
import "NotesModel.js" as NotesModel

Item {
  id: root

  property bool onRight: true
  property bool hovered: false
  property bool editing: false
  property string title: "Untitled"
  property string body: ""
  property string colorId: "yellow"
  property int spineWidth: Style.space(28)
  property int peekWidth: Style.space(240)
  property int hang: Style.cornerRadius
  property real tilt: 0
  property string fontFamily: Style.font.menuFamily

  readonly property var swatch: NotesModel.colorFor(colorId)
  readonly property color paper: swatch.paper
  readonly property color ink: swatch.ink
  readonly property var borderSpec: Border.flat(Util.alpha(swatch.ink, 0.16), Math.max(1, Style.space(1)))
  readonly property int paperRadius: Math.max(Style.cornerRadius, 4)
  readonly property int aaPad: 2
  visible: !editing
  width: (hovered ? peekWidth : spineWidth) + hang
  height: Math.max(Style.space(72), implicitHeight)
  rotation: tilt
  transformOrigin: onRight ? Item.Right : Item.Left
  // Rasterize with padding so the tilt bilinear-filters against transparent
  // pixels. A fill-to-bounds layer clamps to opaque paper and stays jagged.
  antialiasing: true
  layer.enabled: true
  layer.smooth: true
  layer.samples: 4

  signal clicked()
  signal hoverChanged(bool isHovered)
  signal colorPicked(string id)
  signal deleteClicked()

  Behavior on width {
    NumberAnimation {
      duration: root.hovered ? 120 : 80
      easing.type: Easing.OutCubic
    }
  }

  BorderSurface {
    anchors.fill: parent
    anchors.margins: root.aaPad
    color: root.paper
    antialiasing: true
    radius: root.paperRadius
    borderSpec: root.borderSpec
  }

  Item {
    id: spine
    width: root.spineWidth
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.topMargin: root.aaPad
    anchors.bottomMargin: root.aaPad
    anchors.right: root.onRight ? parent.right : undefined
    anchors.left: root.onRight ? undefined : parent.left
    anchors.rightMargin: root.onRight ? root.hang : 0
    anchors.leftMargin: root.onRight ? 0 : root.hang

    // Size the box to the rotated label's visual bounds so centerIn uses
    // the tab thickness, not the unrotated text width.
    Item {
      id: titleBox
      anchors.centerIn: parent
      width: Math.max(1, titleLabel.implicitHeight)
      height: Math.max(1, titleLabel.width)

      Text {
        id: titleLabel
        anchors.centerIn: parent
        width: spine.height - Style.space(16)
        rotation: root.onRight ? -90 : 90
        text: root.title
        color: root.ink
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }

  Item {
    id: peekBody
    visible: root.width > root.spineWidth + root.hang + 8
    opacity: root.hovered ? 1 : 0
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: root.onRight ? parent.left : spine.right
    anchors.right: root.onRight ? spine.left : parent.right
    anchors.margins: Style.space(10)
    clip: true

    Behavior on opacity { NumberAnimation { duration: 100 } }

    Text {
      id: peekTitle
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      text: root.title
      color: root.ink
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      elide: Text.ElideRight
      wrapMode: Text.NoWrap

      TapHandler {
        enabled: !root.editing
        onTapped: root.clicked()
      }
    }

    Flickable {
      id: peekScroll
      anchors.top: peekTitle.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: chrome.top
      anchors.topMargin: Style.spacing.xs
      anchors.bottomMargin: Style.spacing.xs
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height
      contentWidth: width
      contentHeight: peekBodyText.implicitHeight

      Text {
        id: peekBodyText
        width: peekScroll.width
        text: NotesModel.markdownForDisplay(root.body)
        textFormat: Text.MarkdownText
        color: Util.alpha(root.ink, 0.82)
        linkColor: root.ink
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }

      TapHandler {
        enabled: !root.editing
        onTapped: root.clicked()
      }
    }

    NoteChrome {
      id: chrome
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      colorId: root.colorId
      ink: root.ink
      showDelete: true
      onColorPicked: function(id) { root.colorPicked(id) }
      onDeleteClicked: root.deleteClicked()
    }
  }

  HoverHandler {
    enabled: !root.editing
    onHoveredChanged: root.hoverChanged(hovered)
  }

  MouseArea {
    anchors.fill: spine
    enabled: !root.editing
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
