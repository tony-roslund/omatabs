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
  property int maxPeekWidth: Style.space(560)
  property int hang: Style.cornerRadius
  property real tilt: 0
  property int slotY: 0
  property int slotHeight: Style.space(32)
  property int stackHeight: 0
  property string fontFamily: Style.font.menuFamily

  readonly property var swatch: NotesModel.colorFor(colorId)
  readonly property color paper: swatch.paper
  readonly property color ink: swatch.ink
  readonly property var borderSpec: Border.flat(Util.alpha(swatch.ink, 0.16), Math.max(1, Style.space(1)))
  readonly property int paperRadius: Math.max(Style.cornerRadius, 4)
  readonly property int aaPad: 2
  readonly property int peekPad: Style.space(10)
  readonly property int minPeekWidth: Style.space(220)
  readonly property int innerPeekWidth: Math.max(1, fittedPeekWidth - spineWidth - peekPad * 2)
  readonly property int fittedPeekWidth: {
    var natural = Math.ceil(measureNatural.implicitWidth) + peekPad * 2 + spineWidth
    var want = Math.max(minPeekWidth, Math.max(peekWidth, natural))
    var cap = Math.max(minPeekWidth, maxPeekWidth)
    return Math.min(want, cap)
  }
  readonly property int measuredPeekHeight: {
    var titleH = Math.ceil(measureTitle.implicitHeight)
    var bodyH = Math.ceil(measureBody.implicitHeight)
    var chromeH = Style.space(28)
    var h = peekPad * 2 + titleH + Style.spacing.xs + bodyH + Style.spacing.xs + chromeH + 2
    return Math.max(Style.space(88), h)
  }
  readonly property int peekHeight: {
    var avail = Math.max(slotHeight, stackHeight)
    return Math.min(measuredPeekHeight, avail)
  }
  readonly property int peekY: {
    var h = peekHeight
    var y = slotY
    if (stackHeight > 0 && y + h > stackHeight) y = stackHeight - h
    if (y < 0) y = 0
    return y
  }
  readonly property bool peekFits: measuredPeekHeight <= peekHeight + 1
  visible: !editing
  x: 0
  y: hovered ? peekY : slotY
  width: (hovered ? fittedPeekWidth : spineWidth) + hang
  height: hovered ? peekHeight : slotHeight
  rotation: tilt
  transformOrigin: onRight ? Item.Right : Item.Left
  // Layer only while collapsed so hover growth is a real layout change,
  // not a stretched snapshot of the spine.
  antialiasing: true
  layer.enabled: !hovered
  layer.smooth: true
  layer.samples: 4

  signal clicked()
  signal hoverChanged(bool isHovered)
  signal colorPicked(string id)
  signal deleteClicked()

  property bool motionReady: false
  Component.onCompleted: motionReady = true

  Behavior on width {
    enabled: root.motionReady
    NumberAnimation {
      duration: root.hovered ? 220 : 150
      easing.type: Easing.OutCubic
    }
  }
  Behavior on height {
    enabled: root.motionReady
    NumberAnimation {
      duration: root.hovered ? 220 : 150
      easing.type: Easing.OutCubic
    }
  }
  Behavior on y {
    enabled: root.motionReady
    NumberAnimation {
      duration: root.hovered ? 220 : 150
      easing.type: Easing.OutCubic
    }
  }

  Item {
    x: -10000
    y: -10000
    width: 1
    height: 1
    clip: true
    enabled: false

    Text {
      id: measureNatural
      text: NotesModel.markdownForDisplay(NotesModel.sanitizeBody(root.body))
      textFormat: Text.MarkdownText
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.NoWrap
    }

    Text {
      id: measureTitle
      width: root.innerPeekWidth
      text: root.title
      textFormat: Text.PlainText
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      wrapMode: Text.NoWrap
      elide: Text.ElideRight
    }

    Text {
      id: measureBody
      width: root.innerPeekWidth
      text: NotesModel.markdownForDisplay(NotesModel.sanitizeBody(root.body))
      textFormat: Text.MarkdownText
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
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
      height: Math.max(1, titleLabel.implicitWidth)

      Text {
        id: titleLabel
        anchors.centerIn: parent
        rotation: root.onRight ? -90 : 90
        text: root.title
        textFormat: Text.PlainText
        color: root.ink
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
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
      textFormat: Text.PlainText
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
      interactive: root.hovered && !root.peekFits
      contentWidth: width
      contentHeight: peekBodyText.implicitHeight

      Text {
        id: peekBodyText
        width: peekScroll.width
        text: NotesModel.markdownForDisplay(NotesModel.sanitizeBody(root.body))
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
